-- Phase 3A: Enhanced Multi-Child Support (Works with existing tables)
-- This approach enhances your existing devices and parent_child tables

-- 1. Add child_name column to existing devices table
ALTER TABLE public.devices 
ADD COLUMN IF NOT EXISTS child_name TEXT;

-- 2. Add child_name column to existing usage_statistics table
ALTER TABLE public.usage_statistics 
ADD COLUMN IF NOT EXISTS child_name TEXT;

-- 3. Add child_name column to existing usage_records table
ALTER TABLE public.usage_records 
ADD COLUMN IF NOT EXISTS child_name TEXT;

-- 4. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_devices_child_name ON public.devices(child_name);
CREATE INDEX IF NOT EXISTS idx_usage_statistics_child ON public.usage_statistics(child_name);
CREATE INDEX IF NOT EXISTS idx_usage_records_child ON public.usage_records(child_name);

-- 5. Create function to get family summary (all children for a parent)
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

-- 6. Create function to get child-specific statistics
CREATE OR REPLACE FUNCTION get_child_statistics(
    p_user_id TEXT,
    p_child_device_id TEXT,
    p_start_date TEXT,
    p_end_date TEXT
) RETURNS TABLE (
    id UUID,
    user_account_id TEXT,
    child_device_id TEXT,
    child_device_name TEXT,
    child_name TEXT,
    app_name TEXT,
    bundle_identifier TEXT,
    total_requests_approved BIGINT,
    total_time_approved_minutes BIGINT,
    last_approved_date TEXT,
    created_at TEXT,
    updated_at TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        us.id,
        us.user_account_id::text,
        us.child_device_id,
        us.child_device_name,
        us.child_name,
        us.app_name,
        us.bundle_identifier,
        us.total_requests_approved,
        us.total_time_approved_minutes,
        us.last_approved_date::text,
        us.created_at::text,
        us.updated_at::text
    FROM public.usage_statistics us
    WHERE us.user_account_id::text = p_user_id
      AND us.child_device_id = p_child_device_id
      AND us.last_approved_date >= p_start_date::timestamp with time zone
      AND us.last_approved_date < p_end_date::timestamp with time zone
    ORDER BY us.last_approved_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Create function to register child device with name
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
    -- Insert or update device with child name
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
        child_name = EXCLUDED.child_name
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Create function to register parent device
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
        is_parent = EXCLUDED.is_parent
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Create function to get all children for a parent
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

-- 10. Create function to link parent and child devices
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
    DO NOTHING
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. Grant permissions
GRANT EXECUTE ON FUNCTION get_family_summary(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_child_statistics(TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION register_child_device_with_name(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION register_parent_device(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_children_for_parent(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION link_parent_child_devices(UUID, TEXT, TEXT) TO authenticated;

-- 12. Create updated_at trigger function (if not exists)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 13. Add updated_at column to devices table if not exists
ALTER TABLE public.devices 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 14. Create trigger for devices updated_at
DROP TRIGGER IF EXISTS update_devices_updated_at ON public.devices;
CREATE TRIGGER update_devices_updated_at
    BEFORE UPDATE ON public.devices
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
