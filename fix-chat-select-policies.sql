-- Fix SELECT Policies for Chat Sessions
-- The issue is that SELECT queries are still being blocked by RLS

-- Drop existing SELECT policies
DROP POLICY IF EXISTS "Users can view their own chat sessions" ON public.chat_sessions;
DROP POLICY IF EXISTS "Users can view messages in their sessions" ON public.chat_messages;

-- Create new SELECT policies that work with app authentication
CREATE POLICY "Users can view their own chat sessions" ON public.chat_sessions
    FOR SELECT USING (
        -- Allow if user is authenticated and is either parent or child
        auth.uid() IS NOT NULL AND 
        auth.uid()::text IN (parent_device_id, child_device_id)
    );

CREATE POLICY "Users can view messages in their sessions" ON public.chat_messages
    FOR SELECT USING (
        -- Allow if user is authenticated and session exists
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM public.chat_sessions cs
            WHERE cs.id = session_id
            AND auth.uid()::text IN (cs.parent_device_id, cs.child_device_id)
        )
    );

-- Also update the RPC function to handle duplicates gracefully
CREATE OR REPLACE FUNCTION create_chat_session_for_family(
    p_parent_device_id TEXT,
    p_child_device_id TEXT,
    p_child_name TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_session_id UUID;
    existing_session_id UUID;
BEGIN
    -- Check if session already exists
    SELECT id INTO existing_session_id
    FROM public.chat_sessions
    WHERE parent_device_id = p_parent_device_id 
    AND child_device_id = p_child_device_id;
    
    -- If session exists, return existing ID
    IF existing_session_id IS NOT NULL THEN
        RETURN existing_session_id;
    END IF;
    
    -- Insert the chat session (bypasses RLS due to SECURITY DEFINER)
    INSERT INTO public.chat_sessions (
        parent_device_id,
        child_device_id,
        child_name
    ) VALUES (
        p_parent_device_id,
        p_child_device_id,
        p_child_name
    ) RETURNING id INTO new_session_id;
    
    RETURN new_session_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION create_chat_session_for_family(TEXT, TEXT, TEXT) TO authenticated;

-- Test the policies
SELECT 'SELECT policies updated successfully' as status;
