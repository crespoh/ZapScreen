-- Drop existing chat system tables and policies
-- Run this first, then run chat-system-schema.sql

-- Drop RPC functions first (if they exist)
DROP FUNCTION IF EXISTS get_chat_messages(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS get_pending_unlock_requests(TEXT);
DROP FUNCTION IF EXISTS update_unlock_request_status(UUID, TEXT, TEXT);

-- Drop triggers first (if they exist)
DROP TRIGGER IF EXISTS update_chat_sessions_updated_at ON chat_sessions;
DROP TRIGGER IF EXISTS update_unlock_requests_updated_at ON unlock_requests;

-- Drop trigger functions (if they exist) - with CASCADE to handle dependencies
DROP FUNCTION IF EXISTS update_chat_sessions_updated_at() CASCADE;
DROP FUNCTION IF EXISTS update_unlock_requests_updated_at() CASCADE;

-- Drop tables (this will also drop associated policies)
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS unlock_requests CASCADE;
DROP TABLE IF EXISTS chat_sessions CASCADE;

-- Verify tables are dropped
SELECT 'Tables dropped successfully' as status;
