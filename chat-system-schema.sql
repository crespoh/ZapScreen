-- Chat System Database Schema
-- This schema supports real-time communication between parents and children

-- Chat Sessions Table
CREATE TABLE IF NOT EXISTS public.chat_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    parent_device_id TEXT NOT NULL,
    child_device_id TEXT NOT NULL,
    child_name TEXT NOT NULL,
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    unread_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one session per parent-child pair
    UNIQUE(parent_device_id, child_device_id)
);

-- Chat Messages Table
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
    sender_id TEXT NOT NULL,
    sender_name TEXT NOT NULL,
    message_type TEXT NOT NULL CHECK (message_type IN ('text', 'unlock_request', 'unlock_response', 'system')),
    content TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_read BOOLEAN DEFAULT false,
    
    -- For unlock request messages
    unlock_request_id TEXT,
    app_name TEXT,
    requested_duration TEXT,
    unlock_status TEXT CHECK (unlock_status IN ('pending', 'approved', 'denied', 'expired')),
    parent_response TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Unlock Requests Table
CREATE TABLE IF NOT EXISTS public.unlock_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    child_device_id TEXT NOT NULL,
    child_name TEXT NOT NULL,
    app_name TEXT NOT NULL,
    app_bundle_id TEXT NOT NULL,
    requested_duration TEXT NOT NULL,
    request_message TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'denied', 'expired')),
    parent_response TEXT,
    responded_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chat_sessions_parent_device ON public.chat_sessions(parent_device_id);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_child_device ON public.chat_sessions(child_device_id);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_last_message ON public.chat_sessions(last_message_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_messages_session_id ON public.chat_messages(session_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_timestamp ON public.chat_messages(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id ON public.chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_unlock_request_id ON public.chat_messages(unlock_request_id);

CREATE INDEX IF NOT EXISTS idx_unlock_requests_child_device ON public.unlock_requests(child_device_id);
CREATE INDEX IF NOT EXISTS idx_unlock_requests_status ON public.unlock_requests(status);
CREATE INDEX IF NOT EXISTS idx_unlock_requests_timestamp ON public.unlock_requests(timestamp DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE public.chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.unlock_requests ENABLE ROW LEVEL SECURITY;

-- RLS Policies for chat_sessions
CREATE POLICY "Users can view their own chat sessions" ON public.chat_sessions
    FOR SELECT USING (
        auth.uid()::text IN (parent_device_id, child_device_id)
    );

CREATE POLICY "Users can insert their own chat sessions" ON public.chat_sessions
    FOR INSERT WITH CHECK (
        auth.uid()::text IN (parent_device_id, child_device_id)
    );

CREATE POLICY "Users can update their own chat sessions" ON public.chat_sessions
    FOR UPDATE USING (
        auth.uid()::text IN (parent_device_id, child_device_id)
    );

-- RLS Policies for chat_messages
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

-- RLS Policies for unlock_requests
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

-- Functions to automatically update timestamps
CREATE OR REPLACE FUNCTION update_chat_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_unlock_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for automatic timestamp updates
CREATE TRIGGER update_chat_sessions_updated_at_trigger
    BEFORE UPDATE ON public.chat_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_sessions_updated_at();

CREATE TRIGGER update_unlock_requests_updated_at_trigger
    BEFORE UPDATE ON public.unlock_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_unlock_requests_updated_at();

-- Function to get chat messages for a session
CREATE OR REPLACE FUNCTION get_chat_messages(
    p_session_id UUID,
    p_limit TEXT DEFAULT '50',
    p_offset TEXT DEFAULT '0'
)
RETURNS TABLE(
    id UUID,
    session_id UUID,
    sender_id TEXT,
    sender_name TEXT,
    message_type TEXT,
    content TEXT,
    message_timestamp TIMESTAMP WITH TIME ZONE,
    is_read BOOLEAN,
    unlock_request_id TEXT,
    app_name TEXT,
    requested_duration TEXT,
    unlock_status TEXT,
    parent_response TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cm.id,
        cm.session_id,
        cm.sender_id,
        cm.sender_name,
        cm.message_type,
        cm.content,
        cm.timestamp as message_timestamp,
        cm.is_read,
        cm.unlock_request_id,
        cm.app_name,
        cm.requested_duration,
        cm.unlock_status,
        cm.parent_response
    FROM public.chat_messages cm
    WHERE cm.session_id = p_session_id
    ORDER BY cm.timestamp DESC
    LIMIT p_limit::INTEGER
    OFFSET p_offset::INTEGER;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get pending unlock requests for a parent
CREATE OR REPLACE FUNCTION get_pending_unlock_requests(
    p_parent_device_id TEXT
)
RETURNS TABLE(
    id UUID,
    child_device_id TEXT,
    child_name TEXT,
    app_name TEXT,
    app_bundle_id TEXT,
    requested_duration TEXT,
    request_message TEXT,
    request_timestamp TIMESTAMP WITH TIME ZONE,
    status TEXT,
    parent_response TEXT,
    responded_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ur.id,
        ur.child_device_id,
        ur.child_name,
        ur.app_name,
        ur.app_bundle_id,
        ur.requested_duration,
        ur.request_message,
        ur.timestamp as request_timestamp,
        ur.status,
        ur.parent_response,
        ur.responded_at
    FROM public.unlock_requests ur
    INNER JOIN public.chat_sessions cs ON ur.child_device_id = cs.child_device_id
    WHERE cs.parent_device_id = p_parent_device_id
    AND ur.status = 'pending'
    ORDER BY ur.timestamp DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update unlock request status
CREATE OR REPLACE FUNCTION update_unlock_request_status(
    p_request_id UUID,
    p_status TEXT,
    p_parent_response TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.unlock_requests
    SET 
        status = p_status,
        parent_response = p_parent_response,
        responded_at = CASE WHEN p_status IN ('approved', 'denied') THEN NOW() ELSE responded_at END
    WHERE id = p_request_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON public.chat_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.chat_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.unlock_requests TO authenticated;
GRANT EXECUTE ON FUNCTION get_chat_messages(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_unlock_requests(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION update_unlock_request_status(UUID, TEXT, TEXT) TO authenticated;

-- Comments for documentation
COMMENT ON TABLE public.chat_sessions IS 'Stores chat sessions between parents and children';
COMMENT ON TABLE public.chat_messages IS 'Stores individual chat messages including unlock requests';
COMMENT ON TABLE public.unlock_requests IS 'Stores app unlock requests from children to parents';
COMMENT ON FUNCTION get_chat_messages(UUID, TEXT, TEXT) IS 'Retrieves chat messages for a session with pagination';
COMMENT ON FUNCTION get_pending_unlock_requests(TEXT) IS 'Retrieves pending unlock requests for a parent device';
COMMENT ON FUNCTION update_unlock_request_status(UUID, TEXT, TEXT) IS 'Updates the status of an unlock request';
