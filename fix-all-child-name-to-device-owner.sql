-- Comprehensive fix: Update ALL remaining tables to use device_owner instead of child_name
-- This ensures complete consistency across the entire database

-- =====================================================
-- 1. FIX child_shield_settings TABLE
-- =====================================================

-- Rename column
ALTER TABLE child_shield_settings 
RENAME COLUMN child_name TO device_owner;

-- Update unique constraint
ALTER TABLE child_shield_settings 
DROP CONSTRAINT IF EXISTS child_shield_settings_user_account_id_child_device_id_child_name_key;

ALTER TABLE child_shield_settings 
ADD CONSTRAINT child_shield_settings_user_account_id_child_device_id_device_owner_key 
UNIQUE(user_account_id, child_device_id, device_owner);

-- =====================================================
-- 2. FIX unlock_requests TABLE
-- =====================================================

-- Rename column
ALTER TABLE unlock_requests 
RENAME COLUMN child_name TO device_owner;

-- =====================================================
-- 3. FIX usage_records TABLE
-- =====================================================

-- Rename column
ALTER TABLE usage_records 
RENAME COLUMN child_name TO device_owner;

-- =====================================================
-- 4. FIX usage_statistics TABLE
-- =====================================================

-- Rename column
ALTER TABLE usage_statistics 
RENAME COLUMN child_name TO device_owner;

-- =====================================================
-- 5. FIX chat_sessions TABLE
-- =====================================================

-- Rename column
ALTER TABLE chat_sessions 
RENAME COLUMN child_name TO device_owner;

-- =====================================================
-- 6. UPDATE ALL RPC FUNCTIONS
-- =====================================================

-- Drop existing functions first to avoid return type conflicts
DROP FUNCTION IF EXISTS get_child_shield_settings(TEXT, TEXT);
DROP FUNCTION IF EXISTS get_all_children_shield_settings(TEXT);
DROP FUNCTION IF EXISTS upsert_child_shield_setting(UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TIMESTAMP WITH TIME ZONE);
DROP FUNCTION IF EXISTS create_chat_session_for_family(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS create_chat_session_simple(TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS get_pending_unlock_requests(TEXT);

-- Now recreate all functions with the correct return types
-- Update get_child_shield_settings function
CREATE OR REPLACE FUNCTION get_child_shield_settings(
    p_user_account_id TEXT,
    p_child_device_id TEXT
) RETURNS TABLE(
    id TEXT,
    user_account_id TEXT,
    child_device_id TEXT,
    device_owner TEXT,  -- ✅ CHANGED: from child_name to device_owner
    app_name TEXT,
    bundle_identifier TEXT,
    is_shielded BOOLEAN,
    shield_type TEXT,
    unlock_expiry TEXT,
    created_at TEXT,
    updated_at TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        css.id::text,
        css.user_account_id::text,
        css.child_device_id,
        css.device_owner,  -- ✅ CHANGED: from css.child_name to css.device_owner
        css.app_name,
        css.bundle_identifier,
        css.is_shielded,
        css.shield_type,
        css.unlock_expiry::text,
        css.created_at::text,
        css.updated_at::text
    FROM public.child_shield_settings css
    WHERE css.user_account_id::text = p_user_account_id
      AND css.child_device_id = p_child_device_id
    ORDER BY css.app_name ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update get_all_children_shield_settings function
CREATE OR REPLACE FUNCTION get_all_children_shield_settings(
    p_user_account_id TEXT
) RETURNS TABLE(
    id TEXT,
    user_account_id TEXT,
    child_device_id TEXT,
    device_owner TEXT,  -- ✅ CHANGED: from child_name to device_owner
    app_name TEXT,
    bundle_identifier TEXT,
    is_shielded BOOLEAN,
    shield_type TEXT,
    unlock_expiry TEXT,
    created_at TEXT,
    updated_at TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        css.id::text,
        css.user_account_id::text,
        css.child_device_id,
        css.device_owner,  -- ✅ CHANGED: from css.child_name to css.device_owner
        css.app_name,
        css.bundle_identifier,
        css.is_shielded,
        css.shield_type,
        css.unlock_expiry::text,
        css.created_at::text,
        css.updated_at::text
    FROM public.child_shield_settings css
    WHERE css.user_account_id::text = p_user_account_id
    ORDER BY css.device_owner ASC, css.app_name ASC;  -- ✅ CHANGED: from css.child_name to css.device_owner
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update upsert_child_shield_setting function
CREATE OR REPLACE FUNCTION upsert_child_shield_setting(
    p_user_account_id UUID,
    p_child_device_id TEXT,
    p_device_owner TEXT,  -- ✅ CHANGED: from p_child_name to p_device_owner
    p_app_name TEXT,
    p_bundle_identifier TEXT,
    p_is_shielded BOOLEAN,
    p_shield_type TEXT,
    p_unlock_expiry TIMESTAMP WITH TIME ZONE DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO public.child_shield_settings (
        user_account_id,
        child_device_id,
        device_owner,  -- ✅ CHANGED: from child_name to device_owner
        app_name,
        bundle_identifier,
        is_shielded,
        shield_type,
        unlock_expiry
    ) VALUES (
        p_user_account_id,
        p_child_device_id,
        p_device_owner,  -- ✅ CHANGED: from p_child_name to p_device_owner
        p_app_name,
        p_bundle_identifier,
        p_is_shielded,
        p_shield_type,
        p_unlock_expiry
    )
    ON CONFLICT (user_account_id, child_device_id, device_owner)  -- ✅ CHANGED: from child_name to device_owner
    DO UPDATE SET
        app_name = EXCLUDED.app_name,
        is_shielded = EXCLUDED.is_shielded,
        shield_type = EXCLUDED.shield_type,
        unlock_expiry = EXCLUDED.unlock_expiry,
        updated_at = NOW()
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update create_chat_session_for_family function
CREATE OR REPLACE FUNCTION create_chat_session_for_family(
    p_parent_device_id TEXT,
    p_child_device_id TEXT,
    p_device_owner TEXT  -- ✅ CHANGED: from p_child_name to p_device_owner
) RETURNS UUID AS $$
DECLARE
    new_session_id UUID;
    existing_session_id UUID;
BEGIN
    -- Check if session already exists
    SELECT id INTO existing_session_id
    FROM public.chat_sessions
    WHERE parent_device_id = p_parent_device_id 
    AND child_device_id = p_child_device_id;
    
    -- If session exists, return existing ID
    IF existing_session_id IS NOT NULL THEN
        RETURN existing_session_id;
    END IF;
    
    -- Insert the chat session (bypasses RLS due to SECURITY DEFINER)
    INSERT INTO public.chat_sessions (
        parent_device_id,
        child_device_id,
        device_owner  -- ✅ CHANGED: from child_name to device_owner
    ) VALUES (
        p_parent_device_id,
        p_child_device_id,
        p_device_owner  -- ✅ CHANGED: from p_child_name to p_device_owner
    ) RETURNING id INTO new_session_id;
    
    RETURN new_session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update create_chat_session_simple function
CREATE OR REPLACE FUNCTION create_chat_session_simple(
    p_parent_device_id TEXT,
    p_child_device_id TEXT,
    p_device_owner TEXT,  -- ✅ CHANGED: from p_child_name to p_device_owner
    p_parent_name TEXT DEFAULT NULL::TEXT
) RETURNS JSON AS $$
DECLARE
    v_session_id UUID;
    v_session_data JSON;
BEGIN
    -- Insert the chat session
    INSERT INTO chat_sessions (
        parent_device_id,
        child_device_id,
        device_owner,  -- ✅ CHANGED: from child_name to device_owner
        parent_name,
        created_at,
        updated_at
    ) VALUES (
        p_parent_device_id,
        p_child_device_id,
        p_device_owner,  -- ✅ CHANGED: from p_child_name to p_device_owner
        COALESCE(p_parent_name, ''),
        NOW(),
        NOW()
    )
    ON CONFLICT (parent_device_id, child_device_id) 
    DO UPDATE SET
        device_owner = EXCLUDED.device_owner,  -- ✅ CHANGED: from child_name to device_owner
        parent_name = EXCLUDED.parent_name,
        updated_at = NOW()
    RETURNING id INTO v_session_id;
    
    -- Return the created session data
    SELECT row_to_json(cs) INTO v_session_data
    FROM chat_sessions cs
    WHERE cs.id = v_session_id;
    
    RETURN v_session_data;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update get_pending_unlock_requests function
CREATE OR REPLACE FUNCTION get_pending_unlock_requests(
    p_parent_device_id TEXT
) RETURNS TABLE(
    id UUID,
    child_device_id TEXT,
    device_owner TEXT,  -- ✅ CHANGED: from child_name to device_owner
    app_name TEXT,
    app_bundle_id TEXT,
    requested_duration TEXT,
    request_message TEXT,
    request_timestamp TIMESTAMP WITH TIME ZONE,
    status TEXT,
    parent_response TEXT,
    responded_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ur.id,
        ur.child_device_id,
        ur.device_owner,  -- ✅ CHANGED: from ur.child_name to ur.device_owner
        ur.app_name,
        ur.app_bundle_id,
        ur.requested_duration,
        ur.request_message,
        ur.timestamp as request_timestamp,
        ur.status,
        ur.parent_response,
        ur.responded_at
    FROM public.unlock_requests ur
    INNER JOIN public.chat_sessions cs ON ur.child_device_id = cs.child_device_id
    WHERE cs.parent_device_id = p_parent_device_id
    AND ur.status = 'pending'
    ORDER BY ur.timestamp DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 7. GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION get_child_shield_settings(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_children_shield_settings(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_child_shield_setting(UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TIMESTAMP WITH TIME ZONE) TO authenticated;
GRANT EXECUTE ON FUNCTION create_chat_session_for_family(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION create_chat_session_simple(TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_unlock_requests(TEXT) TO authenticated;

-- =====================================================
-- 8. VERIFICATION
-- =====================================================

-- Check all tables for the column rename
SELECT 
    'Column rename verification' as status,
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_name IN ('child_shield_settings', 'unlock_requests', 'usage_records', 'usage_statistics', 'chat_sessions')
AND column_name IN ('child_name', 'device_owner')
ORDER BY table_name, column_name;

-- Show sample data from each table
SELECT 'child_shield_settings sample data:' as table_info;
SELECT device_owner, app_name, bundle_identifier FROM child_shield_settings LIMIT 3;

SELECT 'unlock_requests sample data:' as table_info;
SELECT device_owner, app_name, status FROM unlock_requests LIMIT 3;

SELECT 'usage_records sample data:' as table_info;
SELECT device_owner, app_name, duration_minutes FROM usage_records LIMIT 3;

SELECT 'usage_statistics sample data:' as table_info;
SELECT device_owner, app_name, total_requests_approved FROM usage_statistics LIMIT 3;

SELECT 'chat_sessions sample data:' as table_info;
SELECT device_owner, parent_name FROM chat_sessions LIMIT 3;

-- Check for any remaining child_name references
SELECT 
    'Remaining child_name references found' as warning,
    pt.schemaname,
    pt.tablename,
    ic.column_name
FROM pg_tables pt
JOIN information_schema.columns ic ON pt.tablename = ic.table_name
WHERE ic.column_name = 'child_name'
AND pt.schemaname = 'public';

SELECT 'Comprehensive column rename completed. Please review any warnings above.' as final_status;
