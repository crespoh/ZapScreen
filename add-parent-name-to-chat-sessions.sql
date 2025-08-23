-- Add parent_name column to chat_sessions table
-- This will make the chat system more user-friendly by showing parent names

-- Check current table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'chat_sessions'
ORDER BY ordinal_position;

-- Add parent_name column
ALTER TABLE chat_sessions 
ADD COLUMN IF NOT EXISTS parent_name TEXT;

-- Verify the column was added
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'chat_sessions'
ORDER BY ordinal_position;

-- Show current sessions to see what data we have
SELECT 
    id,
    parent_device_id,
    child_device_id,
    child_name,
    parent_name,
    created_at
FROM chat_sessions 
ORDER BY created_at DESC;

SELECT 'Parent name column added to chat_sessions table' as status;
