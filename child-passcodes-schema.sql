-- Child Passcodes Table Schema
-- This table stores hashed passcodes for child devices so parents can access shield management

-- Create the child_passcodes table
CREATE TABLE IF NOT EXISTS public.child_passcodes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_account_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    child_device_id TEXT NOT NULL,
    hashed_passcode TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one passcode per child device per user
    UNIQUE(user_account_id, child_device_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_child_passcodes_user_account_id ON public.child_passcodes(user_account_id);
CREATE INDEX IF NOT EXISTS idx_child_passcodes_child_device_id ON public.child_passcodes(child_device_id);
CREATE INDEX IF NOT EXISTS idx_child_passcodes_updated_at ON public.child_passcodes(updated_at);

-- Enable Row Level Security (RLS)
ALTER TABLE public.child_passcodes ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Policy: Users can only see their own child passcodes
CREATE POLICY "Users can view their own child passcodes" ON public.child_passcodes
    FOR SELECT USING (auth.uid() = user_account_id);

-- Policy: Users can insert their own child passcodes
CREATE POLICY "Users can insert their own child passcodes" ON public.child_passcodes
    FOR INSERT WITH CHECK (auth.uid() = user_account_id);

-- Policy: Users can update their own child passcodes
CREATE POLICY "Users can update their own child passcodes" ON public.child_passcodes
    FOR UPDATE USING (auth.uid() = user_account_id);

-- Policy: Users can delete their own child passcodes
CREATE POLICY "Users can delete their own child passcodes" ON public.child_passcodes
    FOR DELETE USING (auth.uid() = user_account_id);

-- Function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_child_passcodes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at on row updates
CREATE TRIGGER update_child_passcodes_updated_at_trigger
    BEFORE UPDATE ON public.child_passcodes
    FOR EACH ROW
    EXECUTE FUNCTION update_child_passcodes_updated_at();

-- Function to get the latest passcode for a child device
CREATE OR REPLACE FUNCTION get_latest_child_passcode(
    p_user_account_id UUID,
    p_child_device_id TEXT
)
RETURNS TABLE(
    id UUID,
    user_account_id UUID,
    child_device_id TEXT,
    hashed_passcode TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cp.id,
        cp.user_account_id,
        cp.child_device_id,
        cp.hashed_passcode,
        cp.created_at,
        cp.updated_at
    FROM public.child_passcodes cp
    WHERE cp.user_account_id = p_user_account_id
      AND cp.child_device_id = p_child_device_id
    ORDER BY cp.updated_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.child_passcodes TO authenticated;
GRANT EXECUTE ON FUNCTION get_latest_child_passcode(UUID, TEXT) TO authenticated;

-- Comments for documentation
COMMENT ON TABLE public.child_passcodes IS 'Stores hashed passcodes for child devices to enable parent access to shield management';
COMMENT ON COLUMN public.child_passcodes.hashed_passcode IS 'SHA256 hash of the 4-digit passcode (not the plain text)';
COMMENT ON COLUMN public.child_passcodes.child_device_id IS 'Device ID of the child device that set this passcode';
COMMENT ON FUNCTION get_latest_child_passcode(UUID, TEXT) IS 'Returns the most recent passcode for a child device';
