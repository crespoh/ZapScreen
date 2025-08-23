-- Fix chat_messages table to add receiver_id
-- This addresses the fundamental flaw where we can't track who messages are sent to

-- First, let's check the current table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'chat_messages'
ORDER BY ordinal_position;

-- Add receiver_id column to chat_messages table
ALTER TABLE chat_messages 
ADD COLUMN receiver_id TEXT;

-- Add receiver_name column for better display
ALTER TABLE chat_messages 
ADD COLUMN receiver_name TEXT;

-- Update existing messages to set receiver_id based on session participants
-- For each message, the receiver is the other participant in the session
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

-- Make receiver_id NOT NULL after populating existing data
ALTER TABLE chat_messages 
ALTER COLUMN receiver_id SET NOT NULL;

-- Add index for receiver_id for better performance
CREATE INDEX IF NOT EXISTS idx_chat_messages_receiver_id ON chat_messages(receiver_id);

-- Update the message type check to include 'direct' for direct messages
ALTER TABLE chat_messages 
DROP CONSTRAINT IF EXISTS chat_messages_message_type_check;

ALTER TABLE chat_messages 
ADD CONSTRAINT chat_messages_message_type_check 
CHECK (message_type IN ('text', 'unlock_request', 'unlock_response', 'system', 'direct'));

-- Update RLS policies to consider receiver_id
DROP POLICY IF EXISTS "Users can view messages in their sessions" ON chat_messages;
DROP POLICY IF EXISTS "Users can insert messages in their sessions" ON chat_messages;

CREATE POLICY "Users can view messages in their sessions" ON chat_messages
    FOR SELECT USING (
        auth.uid() IS NOT NULL AND (
            sender_id = auth.uid()::text OR receiver_id = auth.uid()::text
        )
    );

CREATE POLICY "Users can insert messages in their sessions" ON chat_messages
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL AND sender_id = auth.uid()::text
    );

-- Verify the changes
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'chat_messages'
ORDER BY ordinal_position;

-- Show sample of updated messages
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

SELECT 'Chat messages table updated with receiver_id and receiver_name columns' as status;
