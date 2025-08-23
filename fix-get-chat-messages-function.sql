-- Fix get_chat_messages function to match ChatMessage struct
-- This adds missing receiver_id and receiver_name fields and fixes field name mismatches

-- Step 1: Drop the existing function
DROP FUNCTION IF EXISTS get_chat_messages(UUID, TEXT, TEXT);

-- Step 2: Create the updated function with all required fields
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
    receiver_id TEXT,           -- ✅ ADDED: Missing receiver_id field
    receiver_name TEXT,         -- ✅ ADDED: Missing receiver_name field
    message_type TEXT,
    content TEXT,
    message_timestamp TIMESTAMP WITH TIME ZONE,  -- ✅ KEEP as message_timestamp (timestamp is reserved keyword)
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
        cm.receiver_id,         -- ✅ ADDED: Now includes receiver_id
        cm.receiver_name,       -- ✅ ADDED: Now includes receiver_name
        cm.message_type,
        cm.content,
        cm.timestamp as message_timestamp,  -- ✅ Map timestamp to message_timestamp
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

-- Step 3: Grant execute permission
GRANT EXECUTE ON FUNCTION get_chat_messages(UUID, TEXT, TEXT) TO authenticated;

-- Step 4: Add comment
COMMENT ON FUNCTION get_chat_messages(UUID, TEXT, TEXT) IS 'Retrieves chat messages for a session with pagination - Updated to include receiver fields and match ChatMessage struct';

-- Step 5: Verify the function was created correctly
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'get_chat_messages';

-- Step 6: Test the function with a sample call (optional - remove this line if you don't want to test)
-- SELECT * FROM get_chat_messages('00000000-0000-0000-0000-000000000000'::UUID, '1', '0') LIMIT 1;
