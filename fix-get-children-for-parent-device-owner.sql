-- Fix get_children_for_parent function to use device_owner instead of child_name
-- This resolves the error: "column d.child_name does not exist"

-- Drop the existing function
DROP FUNCTION IF EXISTS get_children_for_parent(TEXT);

-- Recreate get_children_for_parent function with correct column references
CREATE OR REPLACE FUNCTION get_children_for_parent(
    p_user_id TEXT
) RETURNS TABLE (
    device_owner TEXT,  -- Changed from child_name to device_owner
    device_name TEXT,
    device_id TEXT,
    device_token TEXT,
    created_at TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.device_owner,  -- Changed from d.child_name to d.device_owner
        d.device_name,
        d.device_id,
        d.device_token,
        d.created_at::text
    FROM public.devices d
    WHERE d.user_account_id::text = p_user_id
      AND d.is_parent = false
      AND d.device_owner IS NOT NULL  -- Changed from d.child_name to d.device_owner
    ORDER BY d.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_children_for_parent(TEXT) TO authenticated;

-- Verify the function exists and has correct structure
SELECT 
    proname,
    proargtypes::regtype[],
    prosrc
FROM pg_proc 
WHERE proname = 'get_children_for_parent';

-- Test the function (optional - uncomment to test)
-- SELECT * FROM get_children_for_parent('your-test-user-id');
