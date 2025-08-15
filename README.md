# ZapScreen Enhanced APN API

This repository contains the enhanced unlock command and event API with idempotency, retries, and structured logging.

## Architecture

```
iOS App → Supabase Edge Functions → Vercel Functions → APNs
```

## Enhanced Features

### 1. Idempotency
- All requests support optional `request_id` parameter
- Duplicate requests with same `request_id` return original result
- Backward compatible - generates UUID if not provided

### 2. Retry Logic
- Bounded retries (3 attempts) with jittered backoff
- Distinguishes between retryable (5xx, 429) and terminal (4xx) errors
- 4-second timeout per attempt

### 3. Structured Logging
- All APN requests logged to `apn_requests` table
- Device tokens hashed for security
- Request status tracking (pending, success, failed, retryable)

### 4. Delivery Seam
- `DELIVERY_MODE` environment variable for future queue support
- Currently supports `direct_vercel` mode
- Easy to add queue-based delivery later

## API Endpoints

### Unlock Command (Parent → Child)
**Endpoint**: `POST /functions/v1/unlock-command`

**Request**:
```json
{
  "request_id": "uuid-optional-for-idempotency",
  "childDeviceId": "device-uuid",
  "bundleIdentifier": "com.example.app",
  "minutes": 15
}
```

**Response**:
```json
{
  "ok": true,
  "apns_id": "apns-message-id",
  "idempotent": false
}
```

### Unlock Event (Child → Parent)
**Endpoint**: `POST /functions/v1/unlock-event`

**Request**:
```json
{
  "request_id": "uuid-optional-for-idempotency",
  "childDeviceId": "device-uuid",
  "bundleIdentifier": "com.example.app"
}
```

**Response**:
```json
{
  "ok": true,
  "apns_id": "apns-message-id",
  "idempotent": false
}
```

### Debug API
**Endpoint**: `POST /functions/v1/debug-apn-request`

**Request**:
```json
{
  "request_id": "your-request-id"
}
```

**Response**:
```json
{
  "request_id": "your-request-id",
  "user_id": "user-uuid",
  "child_device_id": "device-uuid",
  "bundle_identifier": "com.example.app",
  "minutes": 15,
  "status": "success",
  "apns_id": "apns-message-id",
  "created_at": "2024-12-01T00:00:00Z",
  "updated_at": "2024-12-01T00:00:01Z"
}
```

## Environment Variables

### Supabase Edge Functions
```bash
SB_URL=https://droyecamihyazodenamj.supabase.co
SB_ANON_KEY=your_anon_key
VERCEL_APN_EVENT_URL=https://your-vercel-app.vercel.app/api/unlock-event
VERCEL_APN_COMMAND_URL=https://your-vercel-app.vercel.app/api/unlock-command
VERCEL_APN_SECRET=your_shared_secret
DELIVERY_MODE=direct_vercel
APN_BUNDLE_ID=com.ntt.ZapScreen
```

### Vercel Functions
```bash
APN_KEY_ID=your_key_id
APN_TEAM_ID=your_team_id
APN_PRIVATE_KEY=your_p8_key_content
APN_BUNDLE_ID=com.ntt.ZapScreen
APN_ENV=dev
VERCEL_APN_SECRET=your_shared_secret
```

## Database Schema

### apn_requests Table
```sql
CREATE TABLE public.apn_requests (
    request_id TEXT PRIMARY KEY,
    user_id UUID DEFAULT auth.uid(),
    child_device_id TEXT NOT NULL,
    bundle_identifier TEXT NOT NULL,
    minutes INTEGER, -- NULL for unlock-event, required for unlock-command
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed', 'retryable')),
    vercel_status INTEGER,
    apns_id TEXT,
    last_error TEXT,
    device_token_hash TEXT NOT NULL,
    delivery_mode TEXT DEFAULT 'direct_vercel',
    function_type TEXT NOT NULL CHECK (function_type IN ('unlock-event', 'unlock-command')),
    target_device_type TEXT NOT NULL CHECK (target_device_type IN ('parent', 'child'))
);
```

## Testing

### Test Idempotency
```bash
# Send same request twice
curl -X POST https://droyecamihyazodenamj.supabase.co/functions/v1/unlock-command \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "test-123",
    "childDeviceId": "device-uuid",
    "bundleIdentifier": "com.example.app",
    "minutes": 15
  }'

# Second call returns original result with idempotent: true
```

### Test Retry Logic
```bash
# Simulate Vercel 503 error
# Function will retry up to 3 times with backoff
```

### Debug Request
```bash
curl -X POST https://droyecamihyazodenamj.supabase.co/functions/v1/debug-apn-request \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "test-123"
  }'
```

## Deployment

### 1. Database Migration
Run the SQL migration in Supabase Dashboard → SQL Editor

### 2. Deploy Supabase Functions
```bash
cd supabase-functions
supabase functions deploy unlock-event
supabase functions deploy unlock-command
supabase functions deploy debug-apn-request
```

### 3. Deploy Vercel Functions
```bash
cd zap-apn-vercel
vercel --prod
```

### 4. Set Environment Variables
- Configure Supabase Edge Function environment variables
- Configure Vercel environment variables

## Error Handling

### Response Codes
- `200`: Success
- `400`: Bad request (terminal error)
- `401`: Unauthorized
- `404`: Not found
- `503`: Service unavailable (retryable)

### Error Response Format
```json
{
  "ok": false,
  "retryable": true,
  "terminal": false,
  "error": "Service temporarily unavailable"
}
```

## Future Enhancements

### Queue Support
To switch to queue-based delivery:
1. Set `DELIVERY_MODE=enqueue_qstash` (or other queue)
2. Implement queue delivery function
3. No other changes required

### Monitoring
- Query `apn_requests` table for success/failure rates
- Monitor retry patterns
- Track APNs delivery performance

## Security

- Device tokens are hashed before storage
- RLS policies restrict access to user's own requests
- Shared secret validation between Supabase and Vercel
- JWT authentication required for all endpoints
