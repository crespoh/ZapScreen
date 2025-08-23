-- Complete setup for parent name support in chat system
-- Run this script in order to add parent_name column and update RPC function

-- Step 1: Add parent_name column to chat_sessions table
ALTER TABLE chat_sessions 
ADD COLUMN IF NOT EXISTS parent_name TEXT;

-- Step 2: Update existing sessions to have a default parent name
-- This will help with backward compatibility
UPDATE chat_sessions 
SET parent_name = 'Parent' 
WHERE parent_name IS NULL OR parent_name = '';

-- Step 3: Drop the existing RPC function
DROP FUNCTION IF EXISTS create_chat_session_simple(text, text, text);

-- Step 4: Create the updated RPC function with parent_name parameter
CREATE OR REPLACE FUNCTION create_chat_session_simple(
    p_parent_device_id text,
    p_child_device_id text,
    p_child_name text,
    p_parent_name text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_id uuid;
    v_session_data json;
BEGIN
    -- Insert the chat session
    INSERT INTO chat_sessions (
        parent_device_id,
        child_device_id,
        child_name,
        parent_name,
        created_at,
        updated_at
    ) VALUES (
        p_parent_device_id,
        p_child_device_id,
        p_child_name,
        COALESCE(p_parent_name, ''),
        NOW(),
        NOW()
    )
    ON CONFLICT (parent_device_id, child_device_id) 
    DO UPDATE SET
        child_name = EXCLUDED.child_name,
        parent_name = EXCLUDED.parent_name,
        updated_at = NOW()
    RETURNING id INTO v_session_id;
    
    -- Return the created session data
    SELECT row_to_json(cs) INTO v_session_data
    FROM chat_sessions cs
    WHERE cs.id = v_session_id;
    
    RETURN v_session_data;
END;
$$;

-- Step 5: Grant execute permission
GRANT EXECUTE ON FUNCTION create_chat_session_simple(text, text, text, text) TO authenticated;

-- Step 6: Verify the setup
SELECT 
    'Setup completed successfully' as status,
    (SELECT COUNT(*) FROM chat_sessions WHERE parent_name IS NOT NULL) as sessions_with_parent_name,
    (SELECT COUNT(*) FROM chat_sessions) as total_sessions;

-- Step 7: Show current sessions
SELECT 
    id,
    parent_device_id,
    child_device_id,
    child_name,
    parent_name,
    created_at
FROM chat_sessions 
ORDER BY created_at DESC;
