-- Rename child_name to device_owner in devices table
-- This script updates the field name and all related references

-- Step 1: Rename the column in the devices table
ALTER TABLE devices 
RENAME COLUMN child_name TO device_owner;

-- Step 2: Update any existing indexes on the old column name
-- Drop old index if it exists
DROP INDEX IF EXISTS idx_devices_child_name;

-- Create new index with the new column name
CREATE INDEX IF NOT EXISTS idx_devices_device_owner ON public.devices(device_owner);

-- Step 3: Update any views or functions that reference the old column name
-- Check if there are any views that need updating
DO $$
DECLARE
    view_record RECORD;
BEGIN
    FOR view_record IN 
        SELECT schemaname, viewname 
        FROM pg_views 
        WHERE schemaname = 'public' 
        AND definition LIKE '%child_name%'
    LOOP
        RAISE NOTICE 'View % needs manual review for child_name references', view_record.viewname;
    END LOOP;
END $$;

-- Step 4: Update any RPC functions that use the old column name
-- Note: You may need to recreate these functions after updating the column references

-- Step 5: Verify the change
SELECT 
    'Column renamed successfully' as status,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'devices' 
AND column_name IN ('child_name', 'device_owner')
ORDER BY column_name;

-- Step 6: Show sample data to confirm the change
SELECT 
    device_id,
    device_name,
    device_owner,
    is_parent,
    created_at
FROM devices 
LIMIT 5;

-- Step 7: Check for any remaining references to child_name in the database
SELECT 
    'Remaining child_name references found' as warning,
    pt.schemaname,
    pt.tablename,
    ic.column_name
FROM pg_tables pt
JOIN information_schema.columns ic ON pt.tablename = ic.table_name
WHERE ic.column_name = 'child_name'
AND pt.schemaname = 'public';

SELECT 'Column rename completed. Please review any warnings above.' as final_status;
