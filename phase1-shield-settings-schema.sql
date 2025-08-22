-- Phase 1: Child Shield Settings Database Schema
-- Run these commands in your Supabase SQL Editor

-- 1. Create new table for child shield settings
CREATE TABLE IF NOT EXISTS public.child_shield_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_account_id UUID NOT NULL, -- Parent's user account
    child_device_id TEXT NOT NULL, -- Child device identifier
    child_name TEXT NOT NULL,
    app_name TEXT NOT NULL,
    bundle_identifier TEXT NOT NULL,
    is_shielded BOOLEAN NOT NULL DEFAULT true, -- true=shielded, false=unshielded
    shield_type TEXT NOT NULL, -- 'permanent' or 'temporary'
    unlock_expiry TIMESTAMP WITH TIME ZONE, -- NULL for permanent shields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure unique app per child per parent
    UNIQUE(user_account_id, child_device_id, bundle_identifier)
);

-- 2. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_child_shield_user ON public.child_shield_settings(user_account_id);
CREATE INDEX IF NOT EXISTS idx_child_shield_device ON public.child_shield_settings(child_device_id);
CREATE INDEX IF NOT EXISTS idx_child_shield_status ON public.child_shield_settings(is_shielded);
CREATE INDEX IF NOT EXISTS idx_child_shield_bundle ON public.child_shield_settings(bundle_identifier);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.child_shield_settings ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS policies
-- Policy: Users can only see shield settings for their own children
CREATE POLICY "Users can view their own children's shield settings" ON public.child_shield_settings
    FOR SELECT USING (
        user_account_id::text = auth.uid()::text
    );

-- Policy: Users can insert shield settings for their own children
CREATE POLICY "Users can insert shield settings for their own children" ON public.child_shield_settings
    FOR INSERT WITH CHECK (
        user_account_id::text = auth.uid()::text
    );

-- Policy: Users can update shield settings for their own children
CREATE POLICY "Users can update shield settings for their own children" ON public.child_shield_settings
    FOR UPDATE USING (
        user_account_id::text = auth.uid()::text
    );

-- Policy: Users can delete shield settings for their own children
CREATE POLICY "Users can delete shield settings for their own children" ON public.child_shield_settings
    FOR DELETE USING (
        user_account_id::text = auth.uid()::text
    );

-- 5. Create updated_at trigger function (if not exists)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Create trigger for child_shield_settings updated_at
DROP TRIGGER IF EXISTS update_child_shield_settings_updated_at ON public.child_shield_settings;
CREATE TRIGGER update_child_shield_settings_updated_at
    BEFORE UPDATE ON public.child_shield_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 7. Grant permissions to authenticated users
GRANT ALL ON public.child_shield_settings TO authenticated;

-- 8. Create function to upsert shield settings
CREATE OR REPLACE FUNCTION upsert_child_shield_setting(
    p_user_account_id UUID,
    p_child_device_id TEXT,
    p_child_name TEXT,
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
        child_name,
        app_name,
        bundle_identifier,
        is_shielded,
        shield_type,
        unlock_expiry
    ) VALUES (
        p_user_account_id,
        p_child_device_id,
        p_child_name,
        p_app_name,
        p_bundle_identifier,
        p_is_shielded,
        p_shield_type,
        p_unlock_expiry
    )
    ON CONFLICT (user_account_id, child_device_id, bundle_identifier)
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

-- 9. Create function to get shield settings for a specific child
CREATE OR REPLACE FUNCTION get_child_shield_settings(
    p_user_account_id TEXT,
    p_child_device_id TEXT
) RETURNS TABLE (
    id TEXT,
    user_account_id TEXT,
    child_device_id TEXT,
    child_name TEXT,
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
        css.child_name,
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

-- 10. Create function to get all shield settings for a user's children
CREATE OR REPLACE FUNCTION get_all_children_shield_settings(
    p_user_account_id TEXT
) RETURNS TABLE (
    id TEXT,
    user_account_id TEXT,
    child_device_id TEXT,
    child_name TEXT,
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
        css.child_name,
        css.app_name,
        css.bundle_identifier,
        css.is_shielded,
        css.shield_type,
        css.unlock_expiry::text,
        css.created_at::text,
        css.updated_at::text
    FROM public.child_shield_settings css
    WHERE css.user_account_id::text = p_user_account_id
    ORDER BY css.child_name ASC, css.app_name ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION upsert_child_shield_setting(UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TIMESTAMP WITH TIME ZONE) TO authenticated;
GRANT EXECUTE ON FUNCTION get_child_shield_settings(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_children_shield_settings(TEXT) TO authenticated;

-- 12. Verify table creation
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'child_shield_settings'
ORDER BY ordinal_position;
