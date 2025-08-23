-- Create get_parents_for_child function
-- This function mirrors get_children_for_parent but returns parents for a child device

-- Drop the function if it already exists
DROP FUNCTION IF EXISTS get_parents_for_child(TEXT);

-- Create function to get all parents for a child
CREATE OR REPLACE FUNCTION get_parents_for_child(
    p_user_id TEXT
) RETURNS TABLE (
    parent_name TEXT,
    device_name TEXT,
    device_id TEXT,
    device_token TEXT,
    created_at TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.device_name as parent_name,  -- Use device_name as parent_name for parent devices
        d.device_name,
        d.device_id,
        d.device_token,
        d.created_at::text
    FROM public.devices d
    WHERE d.user_account_id::text = p_user_id
      AND d.is_parent = true
      AND d.device_name IS NOT NULL
    ORDER BY d.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_parents_for_child(TEXT) TO authenticated;

-- Test the function
SELECT 'get_parents_for_child function created successfully' as status;

-- Show function details
SELECT 
    proname as function_name,
    proargtypes::regtype[] as parameter_types,
    prorettype::regtype as return_type
FROM pg_proc 
WHERE proname = 'get_parents_for_child';

-- Test with sample data (if any exists)
-- SELECT * FROM get_parents_for_child('your-user-id-here');
