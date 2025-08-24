-- Fix get_family_summary function - PERFECT version based on actual database schema
-- This function will work with your exact table structure

-- Step 1: Drop the existing function
DROP FUNCTION IF EXISTS get_family_summary(TEXT);

-- Step 2: Create the perfect function using your actual schema
CREATE OR REPLACE FUNCTION get_family_summary(
    p_user_id TEXT
)
RETURNS TABLE(
    device_owner TEXT,
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
        d.device_owner,
        d.device_name,
        d.device_id,
        COALESCE(COUNT(DISTINCT css.id), 0)::BIGINT as total_apps,  -- ✅ child_shield_settings exists
        COALESCE(COUNT(DISTINCT ur.id), 0)::BIGINT as total_requests,  -- ✅ unlock_requests exists
        COALESCE(SUM(us.total_time_approved_minutes), 0)::BIGINT as total_minutes,  -- ✅ usage_statistics exists
        COALESCE(
            GREATEST(
                MAX(ur.timestamp),
                MAX(us.last_approved_date),
                d.created_at
            ),
            d.created_at
        ) as last_activity  -- ✅ Use the best available timestamp
    FROM devices d
    INNER JOIN parent_child pc ON d.device_id = pc.child_device_id
    LEFT JOIN child_shield_settings css ON d.device_id = css.child_device_id  -- ✅ Table exists
    LEFT JOIN unlock_requests ur ON d.device_id = ur.child_device_id  -- ✅ Table exists
    LEFT JOIN usage_statistics us ON d.device_id = us.child_device_id  -- ✅ Table exists
    WHERE pc.user_account_id::text = p_user_id  -- ✅ Cast UUID to TEXT
    AND d.is_parent = false
    GROUP BY d.device_owner, d.device_name, d.device_id, d.created_at
    ORDER BY d.device_owner;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Grant execute permission
GRANT EXECUTE ON FUNCTION get_family_summary(TEXT) TO authenticated;

-- Step 4: Add comment
COMMENT ON FUNCTION get_family_summary(TEXT) IS 'PERFECT family summary - Uses actual existing tables: child_shield_settings, unlock_requests, usage_statistics';

-- Step 5: Verify the function was created correctly
SELECT
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname = 'get_family_summary';

-- Step 6: Test the function with a sample call (optional)
-- SELECT * FROM get_family_summary('your-user-id-here') LIMIT 5;
