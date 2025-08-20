-- Fix function overload issue by dropping conflicting functions and recreating with unique names

-- Drop all existing get_family_summary functions
DROP FUNCTION IF EXISTS get_family_summary(TEXT);
DROP FUNCTION IF EXISTS get_family_summary(UUID);
DROP FUNCTION IF EXISTS get_family_summary(text);
DROP FUNCTION IF EXISTS get_family_summary(uuid);

-- Drop all existing get_children_for_parent functions
DROP FUNCTION IF EXISTS get_children_for_parent(TEXT);
DROP FUNCTION IF EXISTS get_children_for_parent(UUID);
DROP FUNCTION IF EXISTS get_children_for_parent(text);
DROP FUNCTION IF EXISTS get_children_for_parent(uuid);

-- Recreate get_family_summary function with TEXT parameter
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

-- Recreate get_children_for_parent function with TEXT parameter
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_family_summary(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_children_for_parent(TEXT) TO authenticated;

-- Verify functions exist
SELECT proname, proargtypes::regtype[] 
FROM pg_proc 
WHERE proname IN ('get_family_summary', 'get_children_for_parent');
