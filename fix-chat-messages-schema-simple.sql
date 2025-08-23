-- Simple fix for chat_messages table - add receiver columns step by step
-- This addresses the missing receiver_id column issue

-- Step 1: Check current table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'chat_messages'
ORDER BY ordinal_position;

-- Step 2: Add receiver_id column (nullable first)
ALTER TABLE chat_messages 
ADD COLUMN IF NOT EXISTS receiver_id TEXT;

-- Step 3: Add receiver_name column
ALTER TABLE chat_messages 
ADD COLUMN IF NOT EXISTS receiver_name TEXT;

-- Step 4: Verify columns were added
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'chat_messages'
ORDER BY ordinal_position;

-- Step 5: Show current data to understand the structure
SELECT 
    id,
    session_id,
    sender_id,
    sender_name,
    receiver_id,
    receiver_name,
    message_type,
    content,
    timestamp
FROM chat_messages 
ORDER BY timestamp DESC 
LIMIT 5;

-- Step 6: Show chat_sessions to understand the relationship
SELECT 
    id,
    parent_device_id,
    child_device_id,
    child_name
FROM chat_sessions 
ORDER BY created_at DESC;

-- Step 7: Update receiver information for existing messages
UPDATE chat_messages 
SET receiver_id = CASE 
    WHEN sender_id = cs.parent_device_id THEN cs.child_device_id
    WHEN sender_id = cs.child_device_id THEN cs.parent_device_id
    ELSE NULL
END,
receiver_name = CASE 
    WHEN sender_id = cs.parent_device_id THEN cs.child_name
    WHEN sender_id = cs.child_device_id THEN 'Parent'
    ELSE NULL
END
FROM chat_sessions cs
WHERE chat_messages.session_id = cs.id;

-- Step 8: Check the results
SELECT 
    COUNT(*) as total_messages,
    COUNT(receiver_id) as messages_with_receiver_id,
    COUNT(*) - COUNT(receiver_id) as messages_with_null_receiver_id
FROM chat_messages;

-- Step 9: Show updated messages
SELECT 
    id,
    session_id,
    sender_id,
    sender_name,
    receiver_id,
    receiver_name,
    message_type,
    content,
    timestamp
FROM chat_messages 
ORDER BY timestamp DESC 
LIMIT 5;

SELECT 'Chat messages table updated with receiver columns' as status;
