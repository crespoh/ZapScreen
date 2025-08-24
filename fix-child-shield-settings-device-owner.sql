-- Fix child_shield_settings table to use device_owner instead of child_name
-- This aligns the table structure with the Swift code expectations

-- Step 1: Rename the column in child_shield_settings table
ALTER TABLE child_shield_settings 
RENAME COLUMN child_name TO device_owner;

-- Step 2: Update any existing indexes on the old column name
-- Drop old index if it exists
DROP INDEX IF EXISTS idx_child_shield_child_name;

-- Create new index with the new column name
CREATE INDEX IF NOT EXISTS idx_child_shield_device_owner ON public.child_shield_settings(device_owner);

-- Step 3: Update the unique constraint to use the new column name
-- Drop the old constraint
ALTER TABLE child_shield_settings 
DROP CONSTRAINT IF EXISTS child_shield_settings_user_account_id_child_device_id_child_name_key;

-- Add the new constraint with device_owner
ALTER TABLE child_shield_settings 
ADD CONSTRAINT child_shield_settings_user_account_id_child_device_id_device_owner_key 
UNIQUE(user_account_id, child_device_id, device_owner);

-- Step 4: Update any RPC functions that reference the old column name
-- Drop existing functions first to avoid return type conflicts
DROP FUNCTION IF EXISTS get_child_shield_settings(TEXT, TEXT);
DROP FUNCTION IF EXISTS get_all_children_shield_settings(TEXT);
DROP FUNCTION IF EXISTS upsert_child_shield_setting(UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TIMESTAMP WITH TIME ZONE);

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

-- Step 5: Grant execute permissions
GRANT EXECUTE ON FUNCTION get_child_shield_settings(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_children_shield_settings(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_child_shield_setting(UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TIMESTAMP WITH TIME ZONE) TO authenticated;

-- Step 6: Verify the changes
SELECT 
    'Column renamed successfully' as status,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'child_shield_settings' 
AND column_name IN ('child_name', 'device_owner')
ORDER BY column_name;

-- Step 7: Show sample data to confirm the change
SELECT 
    id,
    user_account_id,
    child_device_id,
    device_owner,  -- ✅ Now using device_owner
    app_name,
    bundle_identifier,
    is_shielded,
    shield_type
FROM child_shield_settings 
LIMIT 5;

-- Step 8: Check for any remaining references to child_name
SELECT 
    'Remaining child_name references found' as warning,
    pt.schemaname,
    pt.tablename,
    ic.column_name
FROM pg_tables pt
JOIN information_schema.columns ic ON pt.tablename = ic.table_name
WHERE ic.column_name = 'child_name'
AND pt.schemaname = 'public';

SELECT 'Column rename completed. Please review any warnings above.' as final_status;
