-- Debug RLS issue for chat_messages table
-- This will help us understand why inserts are still being blocked

-- 1. Check current RLS policies on chat_messages
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'chat_messages'
ORDER BY policyname;

-- 2. Check if RLS is enabled on chat_messages
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename = 'chat_messages';

-- 3. Check current user context
SELECT 
    current_user,
    session_user,
    auth.uid() as auth_uid,
    auth.role() as auth_role;

-- 4. Check if there are any chat_sessions for the current user
-- (This will help us understand if the session lookup is working)
SELECT 
    id,
    parent_device_id,
    child_device_id,
    child_name
FROM chat_sessions 
WHERE parent_device_id = auth.uid()::text 
   OR child_device_id = auth.uid()::text;

-- 5. Test the RLS policy logic directly
-- This will show us if the session lookup in the policy is working
SELECT 
    'Session lookup test' as test_type,
    COUNT(*) as session_count
FROM chat_sessions 
WHERE parent_device_id = auth.uid()::text 
   OR child_device_id = auth.uid()::text;

-- 6. Show all chat_sessions (for debugging)
SELECT 
    id,
    parent_device_id,
    child_device_id,
    child_name,
    created_at
FROM chat_sessions 
ORDER BY created_at DESC
LIMIT 10;
