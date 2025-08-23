-- Fix the broken chat session that has empty parent_device_id
-- This session was created before we fixed the device ID fallback issue

-- First, let's see what we have
SELECT 
    id,
    parent_device_id,
    child_device_id,
    child_name,
    parent_name,
    created_at
FROM chat_sessions 
WHERE parent_device_id = '' OR parent_device_id IS NULL;

-- Since we can't determine which device should be the parent for this session,
-- and the session is broken, let's delete it and let the app recreate it properly
DELETE FROM chat_sessions 
WHERE parent_device_id = '' OR parent_device_id IS NULL;

-- Verify the broken session is gone
SELECT 
    'Broken session removed' as status,
    (SELECT COUNT(*) FROM chat_sessions WHERE parent_device_id = '' OR parent_device_id IS NULL) as remaining_broken_sessions;

-- Show remaining sessions
SELECT 
    id,
    parent_device_id,
    child_device_id,
    child_name,
    parent_name,
    created_at
FROM chat_sessions 
ORDER BY created_at DESC;
