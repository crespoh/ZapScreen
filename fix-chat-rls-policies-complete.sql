-- Complete Fix for Chat System RLS Policies
-- This fixes the issue where parents can't create chat sessions with their children

-- First, let's see what policies currently exist
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check 
FROM pg_policies 
WHERE tablename IN ('chat_sessions', 'chat_messages', 'unlock_requests')
ORDER BY tablename, policyname;

-- Drop ALL existing policies for chat tables
DROP POLICY IF EXISTS "Users can view their own chat sessions" ON public.chat_sessions;
DROP POLICY IF EXISTS "Users can insert their own chat sessions" ON public.chat_sessions;
DROP POLICY IF EXISTS "Users can update their own chat sessions" ON public.chat_sessions;

DROP POLICY IF EXISTS "Users can view messages in their sessions" ON public.chat_messages;
DROP POLICY IF EXISTS "Users can insert messages in their sessions" ON public.chat_messages;
DROP POLICY IF EXISTS "Users can update their own messages" ON public.chat_messages;

DROP POLICY IF EXISTS "Users can view their own unlock requests" ON public.unlock_requests;
DROP POLICY IF EXISTS "Users can insert their own unlock requests" ON public.unlock_requests;
DROP POLICY IF EXISTS "Users can update their own unlock requests" ON public.unlock_requests;

-- Recreate ALL policies with correct logic

-- Chat Sessions Policies
CREATE POLICY "Users can view their own chat sessions" ON public.chat_sessions
    FOR SELECT USING (
        auth.uid()::text IN (parent_device_id, child_device_id)
    );

CREATE POLICY "Users can insert their own chat sessions" ON public.chat_sessions
    FOR INSERT WITH CHECK (
        auth.uid()::text = parent_device_id
    );

CREATE POLICY "Users can update their own chat sessions" ON public.chat_sessions
    FOR UPDATE USING (
        auth.uid()::text IN (parent_device_id, child_device_id)
    );

-- Chat Messages Policies
CREATE POLICY "Users can view messages in their sessions" ON public.chat_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.chat_sessions cs
            WHERE cs.id = session_id
            AND auth.uid()::text IN (cs.parent_device_id, cs.child_device_id)
        )
    );

CREATE POLICY "Users can insert messages in their sessions" ON public.chat_messages
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.chat_sessions cs
            WHERE cs.id = session_id
            AND auth.uid()::text IN (cs.parent_device_id, cs.child_device_id)
        )
    );

CREATE POLICY "Users can update their own messages" ON public.chat_messages
    FOR UPDATE USING (
        sender_id = auth.uid()::text
    );

-- Unlock Requests Policies
CREATE POLICY "Users can view their own unlock requests" ON public.unlock_requests
    FOR SELECT USING (
        auth.uid()::text = child_device_id
    );

CREATE POLICY "Users can insert their own unlock requests" ON public.unlock_requests
    FOR INSERT WITH CHECK (
        auth.uid()::text = child_device_id
    );

CREATE POLICY "Users can update their own unlock requests" ON public.unlock_requests
    FOR UPDATE USING (
        auth.uid()::text = child_device_id
    );

-- Verify the new policies
SELECT 'New policies created:' as status;
SELECT schemaname, tablename, policyname, cmd, qual, with_check 
FROM pg_policies 
WHERE tablename IN ('chat_sessions', 'chat_messages', 'unlock_requests')
ORDER BY tablename, policyname;

-- Test the current user context
SELECT 'Current auth context:' as status;
SELECT auth.uid() as current_user_id, auth.role() as current_role;
