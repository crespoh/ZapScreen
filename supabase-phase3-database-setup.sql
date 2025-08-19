-- Phase 3A: Multi-Child Data Structure Database Setup
-- Run these commands in your Supabase SQL Editor

-- 1. Create child_devices table for managing child devices
CREATE TABLE IF NOT EXISTS public.child_devices (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_account_id UUID NOT NULL, -- Parent's user account
    device_id TEXT NOT NULL UNIQUE, -- Unique device identifier
    device_name TEXT NOT NULL,
    child_name TEXT NOT NULL, -- Name of the child
    device_token TEXT, -- APN device token
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one device per child per parent
    UNIQUE(user_account_id, child_name)
);

-- 2. Create parent_devices table for managing parent devices
CREATE TABLE IF NOT EXISTS public.parent_devices (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_account_id UUID NOT NULL,
    device_id TEXT NOT NULL UNIQUE,
    device_name TEXT NOT NULL,
    device_token TEXT, -- APN device token
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Enhance usage_statistics table for multi-child support
-- (Add child_name column to existing table)
ALTER TABLE public.usage_statistics 
ADD COLUMN IF NOT EXISTS child_name TEXT;

-- 4. Enhance usage_records table for multi-child support
-- (Add child_name column to existing table)
ALTER TABLE public.usage_records 
ADD COLUMN IF NOT EXISTS child_name TEXT;

-- 5. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_child_devices_user ON public.child_devices(user_account_id);
CREATE INDEX IF NOT EXISTS idx_child_devices_device ON public.child_devices(device_id);
CREATE INDEX IF NOT EXISTS idx_child_devices_child ON public.child_devices(child_name);

CREATE INDEX IF NOT EXISTS idx_parent_devices_user ON public.parent_devices(user_account_id);
CREATE INDEX IF NOT EXISTS idx_parent_devices_device ON public.parent_devices(device_id);

CREATE INDEX IF NOT EXISTS idx_usage_statistics_child ON public.usage_statistics(child_name);
CREATE INDEX IF NOT EXISTS idx_usage_records_child ON public.usage_records(child_name);

-- 6. Enable Row Level Security
ALTER TABLE public.child_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parent_devices ENABLE ROW LEVEL SECURITY;

-- 7. Create RLS policies for child_devices
CREATE POLICY "Users can view their own child devices" ON public.child_devices
    FOR SELECT USING (auth.uid()::text = user_account_id::text);

CREATE POLICY "Users can insert their own child devices" ON public.child_devices
    FOR INSERT WITH CHECK (auth.uid()::text = user_account_id::text);

CREATE POLICY "Users can update their own child devices" ON public.child_devices
    FOR UPDATE USING (auth.uid()::text = user_account_id::text);

CREATE POLICY "Users can delete their own child devices" ON public.child_devices
    FOR DELETE USING (auth.uid()::text = user_account_id::text);

-- 8. Create RLS policies for parent_devices
CREATE POLICY "Users can view their own parent devices" ON public.parent_devices
    FOR SELECT USING (auth.uid()::text = user_account_id::text);

CREATE POLICY "Users can insert their own parent devices" ON public.parent_devices
    FOR INSERT WITH CHECK (auth.uid()::text = user_account_id::text);

CREATE POLICY "Users can update their own parent devices" ON public.parent_devices
    FOR UPDATE USING (auth.uid()::text = user_account_id::text);

CREATE POLICY "Users can delete their own parent devices" ON public.parent_devices
    FOR DELETE USING (auth.uid()::text = user_account_id::text);

-- 9. Update existing RLS policies for usage tables to include child_name
DROP POLICY IF EXISTS "Users can view their own usage statistics" ON public.usage_statistics;
CREATE POLICY "Users can view their own usage statistics" ON public.usage_statistics
    FOR SELECT USING (auth.uid()::text = user_account_id::text);

DROP POLICY IF EXISTS "Users can view their own usage records" ON public.usage_records;
CREATE POLICY "Users can view their own usage records" ON public.usage_records
    FOR SELECT USING (auth.uid()::text = user_account_id::text);

-- 10. Create function to get family summary (all children for a parent)
CREATE OR REPLACE FUNCTION get_family_summary(
    p_user_id TEXT
) RETURNS TABLE (
    child_name TEXT,
    device_name TEXT,
    total_apps BIGINT,
    total_requests BIGINT,
    total_minutes BIGINT,
    last_activity TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        us.child_name,
        us.child_device_name,
        COUNT(DISTINCT us.app_name) as total_apps,
        SUM(us.total_requests_approved) as total_requests,
        SUM(us.total_time_approved_minutes) as total_minutes,
        MAX(us.last_approved_date) as last_activity
    FROM public.usage_statistics us
    WHERE us.user_account_id::text = p_user_id
      AND us.child_name IS NOT NULL
    GROUP BY us.child_name, us.child_device_name
    ORDER BY last_activity DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. Create function to get child-specific statistics
CREATE OR REPLACE FUNCTION get_child_statistics(
    p_user_id TEXT,
    p_child_name TEXT,
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
      AND us.child_name = p_child_name
      AND us.last_approved_date >= p_start_date::timestamp with time zone
      AND us.last_approved_date < p_end_date::timestamp with time zone
    ORDER BY us.last_approved_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 12. Create function to register child device
CREATE OR REPLACE FUNCTION register_child_device(
    p_user_account_id UUID,
    p_device_id TEXT,
    p_device_name TEXT,
    p_child_name TEXT,
    p_device_token TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO public.child_devices (
        user_account_id,
        device_id,
        device_name,
        child_name,
        device_token
    ) VALUES (
        p_user_account_id,
        p_device_id,
        p_device_name,
        p_child_name,
        p_device_token
    )
    ON CONFLICT (user_account_id, child_name)
    DO UPDATE SET
        device_id = EXCLUDED.device_id,
        device_name = EXCLUDED.device_name,
        device_token = EXCLUDED.device_token,
        updated_at = NOW()
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 13. Create function to register parent device
CREATE OR REPLACE FUNCTION register_parent_device(
    p_user_account_id UUID,
    p_device_id TEXT,
    p_device_name TEXT,
    p_device_token TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO public.parent_devices (
        user_account_id,
        device_id,
        device_name,
        device_token
    ) VALUES (
        p_user_account_id,
        p_device_id,
        p_device_name,
        p_device_token
    )
    ON CONFLICT (device_id)
    DO UPDATE SET
        device_name = EXCLUDED.device_name,
        device_token = EXCLUDED.device_token,
        updated_at = NOW()
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 14. Grant permissions
GRANT ALL ON public.child_devices TO authenticated;
GRANT ALL ON public.parent_devices TO authenticated;
GRANT EXECUTE ON FUNCTION get_family_summary(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_child_statistics(TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION register_child_device(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION register_parent_device(UUID, TEXT, TEXT, TEXT) TO authenticated;

-- 15. Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 16. Create triggers for updated_at
CREATE TRIGGER update_child_devices_updated_at
    BEFORE UPDATE ON public.child_devices
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_parent_devices_updated_at
    BEFORE UPDATE ON public.parent_devices
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
