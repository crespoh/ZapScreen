-- Fix get_chat_messages function to return messages in chronological order (oldest first)
-- This ensures messages are displayed in the correct order in the chat

-- Step 1: Drop the existing function
DROP FUNCTION IF EXISTS get_chat_messages(UUID, TEXT, TEXT);

-- Step 2: Create the updated function with chronological ordering
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
    receiver_id TEXT,
    receiver_name TEXT,
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
        cm.receiver_id,
        cm.receiver_name,
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
    ORDER BY cm.timestamp ASC  -- ✅ CHANGED: ASC for chronological order (oldest first)
    LIMIT p_limit::INTEGER
    OFFSET p_offset::INTEGER;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Grant execute permission
GRANT EXECUTE ON FUNCTION get_chat_messages(UUID, TEXT, TEXT) TO authenticated;

-- Step 4: Add comment
COMMENT ON FUNCTION get_chat_messages(UUID, TEXT, TEXT) IS 'Retrieves chat messages for a session with pagination - Returns messages in chronological order (oldest first)';

-- Step 5: Verify the function was created correctly
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'get_chat_messages';

-- Step 6: Test the function with a sample call (optional)
-- SELECT * FROM get_chat_messages('your-session-id-here'::UUID, '10', '0') LIMIT 5;
