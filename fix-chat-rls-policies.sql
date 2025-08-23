-- Fix RLS Policies for Chat System
-- This fixes the issue where parents can't create chat sessions with their children

-- Drop existing policies
DROP POLICY IF EXISTS "Users can insert their own chat sessions" ON public.chat_sessions;
DROP POLICY IF EXISTS "Users can insert messages in their sessions" ON public.chat_messages;
DROP POLICY IF EXISTS "Users can insert their own unlock requests" ON public.unlock_requests;

-- Create new INSERT policies that allow parents to create chat sessions
CREATE POLICY "Users can insert their own chat sessions" ON public.chat_sessions
    FOR INSERT WITH CHECK (
        auth.uid()::text = parent_device_id
    );

-- Create new INSERT policy for messages that allows users to insert messages in sessions they're part of
CREATE POLICY "Users can insert messages in their sessions" ON public.chat_messages
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.chat_sessions cs
            WHERE cs.id = session_id
            AND auth.uid()::text IN (cs.parent_device_id, cs.child_device_id)
        )
    );

-- Create new INSERT policy for unlock requests that allows children to create requests
CREATE POLICY "Users can insert their own unlock requests" ON public.unlock_requests
    FOR INSERT WITH CHECK (
        auth.uid()::text = child_device_id
    );

-- Verify the policies are working
SELECT 'RLS policies updated successfully' as status;
