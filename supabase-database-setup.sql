-- Phase 2: Enhanced Usage Statistics Database Setup
-- Run these commands in your Supabase SQL Editor

-- 1. Create usage_statistics table
CREATE TABLE IF NOT EXISTS public.usage_statistics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_account_id UUID NOT NULL,
    child_device_id TEXT NOT NULL,
    child_device_name TEXT NOT NULL,
    app_name TEXT NOT NULL,
    bundle_identifier TEXT NOT NULL,
    total_requests_approved BIGINT DEFAULT 0,
    total_time_approved_minutes BIGINT DEFAULT 0,
    last_approved_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Composite unique constraint
    UNIQUE(user_account_id, child_device_id, app_name)
);

-- 2. Create usage_records table
CREATE TABLE IF NOT EXISTS public.usage_records (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_account_id UUID NOT NULL,
    child_device_id TEXT NOT NULL,
    child_device_name TEXT NOT NULL,
    app_name TEXT NOT NULL,
    bundle_identifier TEXT NOT NULL,
    approved_date TIMESTAMP WITH TIME ZONE NOT NULL,
    duration_minutes INTEGER NOT NULL,
    request_id TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Index for performance
    UNIQUE(request_id)
);

-- 3. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_usage_statistics_user_device ON public.usage_statistics(user_account_id, child_device_id);
CREATE INDEX IF NOT EXISTS idx_usage_statistics_app ON public.usage_statistics(app_name);
CREATE INDEX IF NOT EXISTS idx_usage_statistics_date ON public.usage_statistics(last_approved_date);

CREATE INDEX IF NOT EXISTS idx_usage_records_user_device ON public.usage_records(user_account_id, child_device_id);
CREATE INDEX IF NOT EXISTS idx_usage_records_app ON public.usage_records(app_name);
CREATE INDEX IF NOT EXISTS idx_usage_records_date ON public.usage_records(approved_date);
CREATE INDEX IF NOT EXISTS idx_usage_records_request ON public.usage_records(request_id);

-- 4. Enable Row Level Security
ALTER TABLE public.usage_statistics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_records ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS policies
CREATE POLICY "Users can view their own usage statistics" ON public.usage_statistics
    FOR SELECT USING (auth.uid()::text = user_account_id::text);

CREATE POLICY "Users can insert their own usage statistics" ON public.usage_statistics
    FOR INSERT WITH CHECK (auth.uid()::text = user_account_id::text);

CREATE POLICY "Users can update their own usage statistics" ON public.usage_statistics
    FOR UPDATE USING (auth.uid()::text = user_account_id::text);

CREATE POLICY "Users can view their own usage records" ON public.usage_records
    FOR SELECT USING (auth.uid()::text = user_account_id::text);

CREATE POLICY "Users can insert their own usage records" ON public.usage_records
    FOR INSERT WITH CHECK (auth.uid()::text = user_account_id::text);

-- 6. Create upsert function for usage_statistics
CREATE OR REPLACE FUNCTION upsert_usage_statistics(
    p_user_account_id UUID,
    p_child_device_id TEXT,
    p_child_device_name TEXT,
    p_app_name TEXT,
    p_bundle_identifier TEXT,
    p_total_requests_approved BIGINT,
    p_total_time_approved_minutes BIGINT,
    p_last_approved_date TIMESTAMP WITH TIME ZONE
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO public.usage_statistics (
        user_account_id,
        child_device_id,
        child_device_name,
        app_name,
        bundle_identifier,
        total_requests_approved,
        total_time_approved_minutes,
        last_approved_date
    ) VALUES (
        p_user_account_id,
        p_child_device_id,
        p_child_device_name,
        p_app_name,
        p_bundle_identifier,
        p_total_requests_approved,
        p_total_time_approved_minutes,
        p_last_approved_date
    )
    ON CONFLICT (user_account_id, child_device_id, app_name)
    DO UPDATE SET
        total_requests_approved = EXCLUDED.total_requests_approved,
        total_time_approved_minutes = EXCLUDED.total_time_approved_minutes,
        last_approved_date = EXCLUDED.last_approved_date,
        updated_at = NOW()
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Create function to get usage statistics for date range
CREATE OR REPLACE FUNCTION get_usage_statistics_for_range(
    p_user_id TEXT,
    p_child_device_id TEXT,
    p_start_date TEXT,
    p_end_date TEXT
) RETURNS TABLE (
    id UUID,
    user_account_id TEXT,
    child_device_id TEXT,
    child_device_name TEXT,
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

-- 8. Create trigger to automatically update usage_statistics when usage_records are inserted
CREATE OR REPLACE FUNCTION update_usage_statistics_on_record_insert()
RETURNS TRIGGER AS $$
BEGIN
    -- Update or insert usage_statistics
    INSERT INTO public.usage_statistics (
        user_account_id,
        child_device_id,
        child_device_name,
        app_name,
        bundle_identifier,
        total_requests_approved,
        total_time_approved_minutes,
        last_approved_date
    ) VALUES (
        NEW.user_account_id,
        NEW.child_device_id,
        NEW.child_device_name,
        NEW.app_name,
        NEW.bundle_identifier,
        1, -- Increment request count
        NEW.duration_minutes, -- Add duration
        NEW.approved_date
    )
    ON CONFLICT (user_account_id, child_device_id, app_name)
    DO UPDATE SET
        total_requests_approved = usage_statistics.total_requests_approved + 1,
        total_time_approved_minutes = usage_statistics.total_time_approved_minutes + NEW.duration_minutes,
        last_approved_date = GREATEST(usage_statistics.last_approved_date, NEW.approved_date),
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Create trigger
DROP TRIGGER IF EXISTS trigger_update_usage_statistics ON public.usage_records;
CREATE TRIGGER trigger_update_usage_statistics
    AFTER INSERT ON public.usage_records
    FOR EACH ROW
    EXECUTE FUNCTION update_usage_statistics_on_record_insert();

-- 10. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.usage_statistics TO authenticated;
GRANT ALL ON public.usage_records TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_usage_statistics TO authenticated;
GRANT EXECUTE ON FUNCTION get_usage_statistics_for_range TO authenticated;
