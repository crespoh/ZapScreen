-- Fix null values in receiver_id column
-- This addresses the 23502 error where receiver_id contains null values

-- First, let's see what messages have null receiver_id
SELECT 
    COUNT(*) as total_messages,
    COUNT(receiver_id) as messages_with_receiver_id,
    COUNT(*) - COUNT(receiver_id) as messages_with_null_receiver_id
FROM chat_messages;

-- Show some examples of messages with null receiver_id
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
WHERE receiver_id IS NULL
ORDER BY timestamp DESC 
LIMIT 5;

-- Update messages with null receiver_id
-- We need to join with chat_sessions to get the correct receiver information
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
WHERE chat_messages.session_id = cs.id
AND chat_messages.receiver_id IS NULL;

-- Check if there are still any null values
SELECT 
    COUNT(*) as total_messages,
    COUNT(receiver_id) as messages_with_receiver_id,
    COUNT(*) - COUNT(receiver_id) as messages_with_null_receiver_id
FROM chat_messages;

-- If there are still null values, let's see what's causing them
SELECT 
    cm.id,
    cm.session_id,
    cm.sender_id,
    cm.sender_name,
    cs.parent_device_id,
    cs.child_device_id,
    cs.child_name
FROM chat_messages cm
LEFT JOIN chat_sessions cs ON cm.session_id = cs.id
WHERE cm.receiver_id IS NULL
ORDER BY cm.timestamp DESC 
LIMIT 10;

-- Now make receiver_id NOT NULL (only if all values are populated)
-- First check if we can safely make it NOT NULL
SELECT 
    CASE 
        WHEN COUNT(*) = COUNT(receiver_id) THEN 'Safe to make NOT NULL'
        ELSE 'Still has null values - cannot make NOT NULL'
    END as status
FROM chat_messages;

-- If safe, make it NOT NULL
-- ALTER TABLE chat_messages ALTER COLUMN receiver_id SET NOT NULL;

-- Show final result
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

SELECT 'Receiver ID null values check completed' as status;
