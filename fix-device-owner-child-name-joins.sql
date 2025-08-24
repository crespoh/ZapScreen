-- Fix all database functions: Ensure device_owner == child_name consistency in JOINs
-- This script fixes functions that JOIN devices table with child-specific tables
-- Critical for maintaining data consistency between device ownership and child operations

-- =====================================================
-- 1. FIX get_family_summary FUNCTION
-- =====================================================

-- Drop existing function
DROP FUNCTION IF EXISTS get_family_summary(TEXT);

-- Create corrected function with proper JOIN conditions
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
        COALESCE(COUNT(DISTINCT css.id), 0)::BIGINT as total_apps,
        COALESCE(COUNT(DISTINCT ur.id), 0)::BIGINT as total_requests,
        COALESCE(SUM(us.total_time_approved_minutes), 0)::BIGINT as total_minutes,
        COALESCE(
            GREATEST(
                MAX(ur.timestamp),
                MAX(us.last_approved_date),
                d.created_at
            ),
            d.created_at
        ) as last_activity
    FROM devices d
    INNER JOIN parent_child pc ON d.device_id = pc.child_device_id
    -- ✅ CRITICAL FIX: Add device_owner == child_name JOIN conditions
    LEFT JOIN child_shield_settings css ON d.device_id = css.child_device_id 
        AND d.device_owner = css.child_name  -- ✅ Ensure consistency
    LEFT JOIN unlock_requests ur ON d.device_id = ur.child_device_id 
        AND d.device_owner = ur.child_name  -- ✅ Ensure consistency
    LEFT JOIN usage_statistics us ON d.device_id = us.child_device_id 
        AND d.device_owner = us.child_name  -- ✅ Ensure consistency
    WHERE pc.user_account_id::text = p_user_id
    AND d.is_parent = false
    GROUP BY d.device_owner, d.device_name, d.device_id, d.created_at
    ORDER BY d.device_owner;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 2. FIX get_children_for_parent FUNCTION
-- =====================================================

-- Drop existing function
DROP FUNCTION IF EXISTS get_children_for_parent(TEXT);

-- Create corrected function with proper JOIN conditions
CREATE OR REPLACE FUNCTION get_children_for_parent(
    p_user_id TEXT
) RETURNS TABLE (
    device_owner TEXT,
    device_name TEXT,
    device_id TEXT,
    device_token TEXT,
    created_at TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.device_owner,
        d.device_name,
        d.device_id,
        d.device_token,
        d.created_at::text
    FROM public.devices d
    WHERE d.user_account_id::text = p_user_id
      AND d.is_parent = false
      AND d.device_owner IS NOT NULL
    ORDER BY d.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 3. FIX get_parents_for_child FUNCTION
-- =====================================================

-- Drop existing function
DROP FUNCTION IF EXISTS get_parents_for_child(TEXT);

-- Create corrected function with proper JOIN conditions
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
        d.device_owner as parent_name,  -- ✅ Use device_owner for parent name
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

-- =====================================================
-- 4. CREATE NEW FUNCTION: get_child_device_consistency
-- =====================================================

-- This function helps verify data consistency between devices and child tables
CREATE OR REPLACE FUNCTION get_child_device_consistency(
    p_user_id TEXT
) RETURNS TABLE (
    device_id TEXT,
    device_owner TEXT,
    child_name_mismatch BOOLEAN,
    shield_settings_count BIGINT,
    unlock_requests_count BIGINT,
    usage_records_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.device_id,
        d.device_owner,
        -- ✅ Check for mismatches between device_owner and child_name
        CASE 
            WHEN d.device_owner != COALESCE(css.child_name, ur.child_name, ur2.child_name)
            THEN true
            ELSE false
        END as child_name_mismatch,
        COUNT(DISTINCT css.id) as shield_settings_count,
        COUNT(DISTINCT ur.id) as unlock_requests_count,
        COUNT(DISTINCT ur2.id) as usage_records_count
    FROM devices d
    LEFT JOIN child_shield_settings css ON d.device_id = css.child_device_id
    LEFT JOIN unlock_requests ur ON d.device_id = ur.child_device_id
    LEFT JOIN usage_records ur2 ON d.device_id = ur2.child_device_id
    WHERE d.user_account_id::text = p_user_id
    AND d.is_parent = false
    GROUP BY d.device_id, d.device_owner, css.child_name, ur.child_name, ur2.child_name
    ORDER BY d.device_owner;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 5. CREATE NEW FUNCTION: fix_child_name_consistency
-- =====================================================

-- This function helps fix any data inconsistencies
CREATE OR REPLACE FUNCTION fix_child_name_consistency(
    p_user_id TEXT
) RETURNS TABLE (
    table_name TEXT,
    records_updated BIGINT,
    status TEXT
) AS $$
DECLARE
    v_updated_count BIGINT;
BEGIN
    -- Fix child_shield_settings inconsistencies
    UPDATE child_shield_settings 
    SET child_name = d.device_owner
    FROM devices d
    WHERE child_shield_settings.child_device_id = d.device_id
    AND child_shield_settings.child_name != d.device_owner
    AND d.user_account_id::text = p_user_id
    AND d.is_parent = false;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    RETURN QUERY SELECT 
        'child_shield_settings'::TEXT,
        v_updated_count,
        'Updated ' || v_updated_count || ' records'::TEXT;
    
    -- Fix unlock_requests inconsistencies
    UPDATE unlock_requests 
    SET child_name = d.device_owner
    FROM devices d
    WHERE unlock_requests.child_device_id = d.device_id
    AND unlock_requests.child_name != d.device_owner
    AND d.user_account_id::text = p_user_id
    AND d.is_parent = false;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    RETURN QUERY SELECT 
        'unlock_requests'::TEXT,
        v_updated_count,
        'Updated ' || v_updated_count || ' records'::TEXT;
    
    -- Fix usage_records inconsistencies
    UPDATE usage_records 
    SET child_name = d.device_owner
    FROM devices d
    WHERE usage_records.child_device_id = d.device_id
    AND usage_records.child_name != d.device_owner
    AND d.user_account_id::text = p_user_id
    AND d.is_parent = false;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    RETURN QUERY SELECT 
        'usage_records'::TEXT,
        v_updated_count,
        'Updated ' || v_updated_count || ' records'::TEXT;
    
    -- Fix usage_statistics inconsistencies
    UPDATE usage_statistics 
    SET child_name = d.device_owner
    FROM devices d
    WHERE usage_statistics.child_device_id = d.device_id
    AND usage_statistics.child_name != d.device_owner
    AND d.user_account_id::text = p_user_id
    AND d.is_parent = false;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    RETURN QUERY SELECT 
        'usage_statistics'::TEXT,
        v_updated_count,
        'Updated ' || v_updated_count || ' records'::TEXT;
    
    -- Fix chat_sessions inconsistencies
    UPDATE chat_sessions 
    SET child_name = d.device_owner
    FROM devices d
    WHERE chat_sessions.child_device_id = d.device_id
    AND chat_sessions.child_name != d.device_owner
    AND d.user_account_id::text = p_user_id
    AND d.is_parent = false;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    RETURN QUERY SELECT 
        'chat_sessions'::TEXT,
        v_updated_count,
        'Updated ' || v_updated_count || ' records'::TEXT;
    
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 6. GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION get_family_summary(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_children_for_parent(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_parents_for_child(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_child_device_consistency(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fix_child_name_consistency(TEXT) TO authenticated;

-- =====================================================
-- 7. VERIFICATION AND TESTING
-- =====================================================

-- Check for any existing data inconsistencies
SELECT 'Checking for data inconsistencies...' as status;

-- Show any mismatches between device_owner and child_name
SELECT 
    'Data consistency check:' as check_type,
    d.device_id,
    d.device_owner,
    css.child_name as shield_child_name,
    ur.child_name as unlock_child_name,
    ur2.child_name as usage_child_name,
    CASE 
        WHEN d.device_owner != COALESCE(css.child_name, ur.child_name, ur2.child_name)
        THEN 'MISMATCH DETECTED'
        ELSE 'Consistent'
    END as status
FROM devices d
LEFT JOIN child_shield_settings css ON d.device_id = css.child_device_id
LEFT JOIN unlock_requests ur ON d.device_id = ur.child_device_id
LEFT JOIN usage_records ur2 ON d.device_id = ur2.child_device_id
WHERE d.is_parent = false
AND (css.child_name IS NOT NULL OR ur.child_name IS NOT NULL OR ur2.child_name IS NOT NULL)
ORDER BY d.device_owner;

-- Test the consistency function
SELECT 'Testing consistency function...' as status;
SELECT * FROM get_child_device_consistency('your-test-user-id') LIMIT 5;

SELECT 'All JOIN consistency fixes applied. Use fix_child_name_consistency() to resolve any data mismatches.' as final_status;
