-- Fix RLS policies for chat_messages table
-- This script addresses the 42501 error when trying to insert chat messages

-- First, check if the tables exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'chat_messages') THEN
        RAISE EXCEPTION 'chat_messages table does not exist. Please run chat-system-schema.sql first.';
    END IF;
    
    IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'unlock_requests') THEN
        RAISE EXCEPTION 'unlock_requests table does not exist. Please run chat-system-schema.sql first.';
    END IF;
END $$;

-- Check if session_id column exists in chat_messages
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'chat_messages' AND column_name = 'session_id'
    ) THEN
        RAISE EXCEPTION 'session_id column does not exist in chat_messages table. Please run chat-system-schema.sql first.';
    END IF;
END $$;

-- Drop existing policies for chat_messages
DROP POLICY IF EXISTS "Users can view messages in their chat sessions" ON chat_messages;
DROP POLICY IF EXISTS "Users can insert messages in their chat sessions" ON chat_messages;
DROP POLICY IF EXISTS "Users can update their own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can delete their own messages" ON chat_messages;

-- Create more permissive policies for chat_messages
-- SELECT policy - allow users to view messages in sessions they participate in
CREATE POLICY "Users can view messages in their chat sessions" ON chat_messages
    FOR SELECT USING (
        auth.uid() IS NOT NULL AND (
            session_id IN (
                SELECT id FROM chat_sessions 
                WHERE parent_device_id = auth.uid()::text 
                   OR child_device_id = auth.uid()::text
            )
        )
    );

-- INSERT policy - allow users to insert messages in sessions they participate in
CREATE POLICY "Users can insert messages in their chat sessions" ON chat_messages
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL AND (
            session_id IN (
                SELECT id FROM chat_sessions 
                WHERE parent_device_id = auth.uid()::text 
                   OR child_device_id = auth.uid()::text
            )
        )
    );

-- UPDATE policy - allow users to update their own messages
CREATE POLICY "Users can update their own messages" ON chat_messages
    FOR UPDATE USING (
        auth.uid() IS NOT NULL AND sender_id = auth.uid()::text
    );

-- DELETE policy - allow users to delete their own messages
CREATE POLICY "Users can delete their own messages" ON chat_messages
    FOR DELETE USING (
        auth.uid() IS NOT NULL AND sender_id = auth.uid()::text
    );

-- Also fix the unlock_requests table RLS policies
DROP POLICY IF EXISTS "Users can view unlock requests in their sessions" ON unlock_requests;
DROP POLICY IF EXISTS "Users can insert unlock requests in their sessions" ON unlock_requests;
DROP POLICY IF EXISTS "Users can update unlock requests in their sessions" ON unlock_requests;

CREATE POLICY "Users can view unlock requests in their sessions" ON unlock_requests
    FOR SELECT USING (
        auth.uid() IS NOT NULL AND (
            child_device_id = auth.uid()::text
            OR child_device_id IN (
                SELECT child_device_id FROM chat_sessions 
                WHERE parent_device_id = auth.uid()::text
            )
        )
    );

CREATE POLICY "Users can insert unlock requests in their sessions" ON unlock_requests
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL AND child_device_id = auth.uid()::text
    );

CREATE POLICY "Users can update unlock requests in their sessions" ON unlock_requests
    FOR UPDATE USING (
        auth.uid() IS NOT NULL AND (
            child_device_id = auth.uid()::text
            OR child_device_id IN (
                SELECT child_device_id FROM chat_sessions 
                WHERE parent_device_id = auth.uid()::text
            )
        )
    );

-- Verify the policies are created
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename IN ('chat_messages', 'unlock_requests')
ORDER BY tablename, policyname;

SELECT 'Chat messages and unlock requests RLS policies updated successfully' as status;
