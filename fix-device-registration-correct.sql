-- Fix device registration functions using the actual table structure
-- Based on the actual devices and parent_child tables

-- First, add the missing unique constraint on device_id
ALTER TABLE public.devices 
ADD CONSTRAINT devices_device_id_unique UNIQUE (device_id);

-- Drop the problematic functions first
DROP FUNCTION IF EXISTS register_child_device_with_name(UUID, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS register_parent_device(UUID, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS get_children_for_parent(TEXT);
DROP FUNCTION IF EXISTS get_family_summary(TEXT);
DROP FUNCTION IF EXISTS link_parent_child_devices(UUID, TEXT, TEXT);

-- Create corrected function to register child device with name
CREATE OR REPLACE FUNCTION register_child_device_with_name(
    p_user_account_id UUID,
    p_device_id TEXT,
    p_device_name TEXT,
    p_child_name TEXT,
    p_device_token TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    -- Insert or update device as child
    INSERT INTO public.devices (
        device_token,
        device_id,
        device_name,
        is_parent,
        user_account_id,
        child_name
    ) VALUES (
        p_device_token,
        p_device_id,
        p_device_name,
        false, -- This is a child device
        p_user_account_id,
        p_child_name
    )
    ON CONFLICT (device_id)
    DO UPDATE SET
        device_name = EXCLUDED.device_name,
        device_token = EXCLUDED.device_token,
        child_name = EXCLUDED.child_name,
        updated_at = NOW()
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create corrected function to register parent device
CREATE OR REPLACE FUNCTION register_parent_device(
    p_user_account_id UUID,
    p_device_id TEXT,
    p_device_name TEXT,
    p_device_token TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    -- Insert or update device as parent
    INSERT INTO public.devices (
        device_token,
        device_id,
        device_name,
        is_parent,
        user_account_id,
        child_name
    ) VALUES (
        p_device_token,
        p_device_id,
        p_device_name,
        true, -- This is a parent device
        p_user_account_id,
        NULL -- Parent devices don't have child_name
    )
    ON CONFLICT (device_id)
    DO UPDATE SET
        device_name = EXCLUDED.device_name,
        device_token = EXCLUDED.device_token,
        is_parent = EXCLUDED.is_parent,
        updated_at = NOW()
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get all children for a parent
CREATE OR REPLACE FUNCTION get_children_for_parent(
    p_user_id TEXT
) RETURNS TABLE (
    child_name TEXT,
    device_name TEXT,
    device_id TEXT,
    device_token TEXT,
    created_at TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.child_name,
        d.device_name,
        d.device_id,
        d.device_token,
        d.created_at::text
    FROM public.devices d
    WHERE d.user_account_id::text = p_user_id
      AND d.is_parent = false
      AND d.child_name IS NOT NULL
    ORDER BY d.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get family summary
CREATE OR REPLACE FUNCTION get_family_summary(
    p_user_id TEXT
) RETURNS TABLE (
    child_name TEXT,
    device_name TEXT,
    device_id TEXT,
    total_apps BIGINT,
    total_requests BIGINT,
    total_minutes BIGINT,
    last_activity TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(us.child_name, 'Unknown Child') as child_name,
        us.child_device_name,
        us.child_device_id,
        COUNT(DISTINCT us.app_name) as total_apps,
        SUM(us.total_requests_approved) as total_requests,
        SUM(us.total_time_approved_minutes) as total_minutes,
        MAX(us.last_approved_date) as last_activity
    FROM public.usage_statistics us
    WHERE us.user_account_id::text = p_user_id
    GROUP BY us.child_name, us.child_device_name, us.child_device_id
    ORDER BY last_activity DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to link parent and child devices
CREATE OR REPLACE FUNCTION link_parent_child_devices(
    p_user_account_id UUID,
    p_parent_device_id TEXT,
    p_child_device_id TEXT
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    -- Insert parent-child relationship
    INSERT INTO public.parent_child (
        parent_device_id,
        child_device_id,
        user_account_id
    ) VALUES (
        p_parent_device_id,
        p_child_device_id,
        p_user_account_id
    )
    ON CONFLICT (parent_device_id, child_device_id)
    DO UPDATE SET
        user_account_id = EXCLUDED.user_account_id
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION register_child_device_with_name(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION register_parent_device(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_children_for_parent(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_family_summary(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION link_parent_child_devices(UUID, TEXT, TEXT) TO authenticated;

-- Verify functions exist
SELECT proname, proargtypes::regtype[] 
FROM pg_proc 
WHERE proname IN ('register_child_device_with_name', 'register_parent_device', 'get_children_for_parent', 'get_family_summary', 'link_parent_child_devices');
