-- Complete Supabase Database Schema for ZapScreen
-- Generated on: 2025-01-23
-- This file contains the complete database structure for reference and debugging

-- =====================================================
-- TABLE DEFINITIONS
-- =====================================================

-- Table: apn_requests
CREATE TABLE IF NOT EXISTS public.apn_requests (
    request_id TEXT PRIMARY KEY,
    user_id UUID DEFAULT auth.uid(),
    child_device_id TEXT NOT NULL,
    bundle_identifier TEXT NOT NULL,
    minutes INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    status TEXT NOT NULL DEFAULT 'pending',
    vercel_status INTEGER,
    apns_id TEXT,
    last_error TEXT,
    device_token_hash TEXT NOT NULL,
    delivery_mode TEXT DEFAULT 'direct_vercel',
    function_type TEXT NOT NULL,
    target_device_type TEXT NOT NULL
);

-- Table: chat_messages
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL,
    sender_id TEXT NOT NULL,
    sender_name TEXT NOT NULL,
    message_type TEXT NOT NULL,
    content TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT now(),
    is_read BOOLEAN DEFAULT false,
    unlock_request_id TEXT,
    app_name TEXT,
    requested_duration TEXT,
    unlock_status TEXT,
    parent_response TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    receiver_id TEXT,
    receiver_name TEXT
);

-- Table: chat_sessions
CREATE TABLE IF NOT EXISTS public.chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_device_id TEXT NOT NULL,
    child_device_id TEXT NOT NULL,
    child_name TEXT NOT NULL,
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    unread_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    parent_name TEXT,
    UNIQUE(parent_device_id, child_device_id)
);

-- Table: child_passcodes
CREATE TABLE IF NOT EXISTS public.child_passcodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_account_id UUID NOT NULL,
    child_device_id TEXT NOT NULL,
    hashed_passcode TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    salt TEXT NOT NULL,
    UNIQUE(user_account_id, child_device_id)
);

-- Table: child_shield_settings
CREATE TABLE IF NOT EXISTS public.child_shield_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_account_id UUID NOT NULL,
    child_device_id TEXT NOT NULL,
    child_name TEXT NOT NULL,
    app_name TEXT NOT NULL,
    bundle_identifier TEXT NOT NULL,
    is_shielded BOOLEAN NOT NULL DEFAULT true,
    shield_type TEXT NOT NULL,
    unlock_expiry TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(user_account_id, child_device_id, bundle_identifier)
);

-- Table: devices
CREATE TABLE IF NOT EXISTS public.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_token TEXT NOT NULL,
    device_id TEXT NOT NULL,
    device_name TEXT NOT NULL,
    is_parent BOOLEAN NOT NULL,
    user_account_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    device_owner TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(device_id),
    UNIQUE(device_token)
);

-- Table: parent_child
CREATE TABLE IF NOT EXISTS public.parent_child (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_device_id TEXT NOT NULL,
    child_device_id TEXT NOT NULL,
    user_account_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    UNIQUE(parent_device_id, child_device_id)
);

-- Table: unlock_requests
CREATE TABLE IF NOT EXISTS public.unlock_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_device_id TEXT NOT NULL,
    child_name TEXT NOT NULL,
    app_name TEXT NOT NULL,
    app_bundle_id TEXT NOT NULL,
    requested_duration TEXT NOT NULL,
    request_message TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT now(),
    status TEXT NOT NULL DEFAULT 'pending',
    parent_response TEXT,
    responded_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Table: usage_records
CREATE TABLE IF NOT EXISTS public.usage_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_account_id UUID NOT NULL,
    child_device_id TEXT NOT NULL,
    child_device_name TEXT NOT NULL,
    app_name TEXT NOT NULL,
    bundle_identifier TEXT NOT NULL,
    approved_date TIMESTAMP WITH TIME ZONE NOT NULL,
    duration_minutes INTEGER NOT NULL,
    request_id TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    child_name TEXT
);

-- Table: usage_statistics
CREATE TABLE IF NOT EXISTS public.usage_statistics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_account_id UUID NOT NULL,
    child_device_id TEXT NOT NULL,
    child_device_name TEXT NOT NULL,
    app_name TEXT NOT NULL,
    bundle_identifier TEXT NOT NULL,
    total_requests_approved INTEGER NOT NULL DEFAULT 0,
    total_time_approved_minutes INTEGER NOT NULL DEFAULT 0,
    last_approved_date TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    child_name TEXT,
    UNIQUE(user_account_id, child_device_id, app_name)
);

-- =====================================================
-- INDEXES
-- =====================================================

-- apn_requests indexes
CREATE INDEX IF NOT EXISTS idx_apn_requests_child_device_id ON public.apn_requests(child_device_id);
CREATE INDEX IF NOT EXISTS idx_apn_requests_created_at ON public.apn_requests(created_at);
CREATE INDEX IF NOT EXISTS idx_apn_requests_function_type ON public.apn_requests(function_type);
CREATE INDEX IF NOT EXISTS idx_apn_requests_status ON public.apn_requests(status);
CREATE INDEX IF NOT EXISTS idx_apn_requests_target_device_type ON public.apn_requests(target_device_type);
CREATE INDEX IF NOT EXISTS idx_apn_requests_user_id ON public.apn_requests(user_id);

-- chat_messages indexes
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id ON public.chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_session_id ON public.chat_messages(session_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_timestamp ON public.chat_messages(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_unlock_request_id ON public.chat_messages(unlock_request_id);

-- chat_sessions indexes
CREATE INDEX IF NOT EXISTS idx_chat_sessions_child_device ON public.chat_sessions(child_device_id);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_last_message ON public.chat_sessions(last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_parent_device ON public.chat_sessions(parent_device_id);

-- child_passcodes indexes
CREATE INDEX IF NOT EXISTS idx_child_passcodes_child_device_id ON public.child_passcodes(child_device_id);
CREATE INDEX IF NOT EXISTS idx_child_passcodes_updated_at ON public.child_passcodes(updated_at);
CREATE INDEX IF NOT EXISTS idx_child_passcodes_user_account_id ON public.child_passcodes(user_account_id);

-- child_shield_settings indexes
CREATE INDEX IF NOT EXISTS idx_child_shield_bundle ON public.child_shield_settings(bundle_identifier);
CREATE INDEX IF NOT EXISTS idx_child_shield_device ON public.child_shield_settings(child_device_id);
CREATE INDEX IF NOT EXISTS idx_child_shield_status ON public.child_shield_settings(is_shielded);
CREATE INDEX IF NOT EXISTS idx_child_shield_user ON public.child_shield_settings(user_account_id);

-- devices indexes
CREATE INDEX IF NOT EXISTS idx_devices_device_owner ON public.devices(device_owner);

-- unlock_requests indexes
CREATE INDEX IF NOT EXISTS idx_unlock_requests_child_device ON public.unlock_requests(child_device_id);
CREATE INDEX IF NOT EXISTS idx_unlock_requests_status ON public.unlock_requests(status);
CREATE INDEX IF NOT EXISTS idx_unlock_requests_timestamp ON public.unlock_requests(timestamp DESC);

-- usage_records indexes
CREATE INDEX IF NOT EXISTS idx_usage_records_app ON public.usage_records(app_name);
CREATE INDEX IF NOT EXISTS idx_usage_records_child ON public.usage_records(child_name);
CREATE INDEX IF NOT EXISTS idx_usage_records_date ON public.usage_records(approved_date);
CREATE INDEX IF NOT EXISTS idx_usage_records_request ON public.usage_records(request_id);
CREATE INDEX IF NOT EXISTS idx_usage_records_user_device ON public.usage_records(user_account_id, child_device_id);

-- usage_statistics indexes
CREATE INDEX IF NOT EXISTS idx_usage_statistics_app_name ON public.usage_statistics(app_name);
CREATE INDEX IF NOT EXISTS idx_usage_statistics_child ON public.usage_statistics(child_name);
CREATE INDEX IF NOT EXISTS idx_usage_statistics_date ON public.usage_statistics(last_approved_date);
CREATE INDEX IF NOT EXISTS idx_usage_statistics_user_device ON public.usage_statistics(user_account_id, child_device_id);

-- =====================================================
-- NOTES
-- =====================================================

-- Key observations:
-- 1. devices table has device_owner column (renamed from child_name)
-- 2. All tables exist and are properly indexed
-- 3. UUID fields are properly handled with ::text casting
-- 4. Timestamps are consistently TIMESTAMP WITH TIME ZONE
-- 5. Foreign key relationships are maintained through device_id fields

-- This schema supports:
-- - Device management (parent/child relationships)
-- - Chat system (sessions and messages)
-- - Shield settings (app blocking)
-- - Unlock requests (temporary app access)
-- - Usage tracking (statistics and records)
-- - APN notifications (push messaging)
