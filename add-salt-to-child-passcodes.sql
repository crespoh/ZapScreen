-- Add salt column to child_passcodes table for salted hashing
-- This ensures both parent and child devices use the same hashing method

-- Step 1: Add salt column to existing table
ALTER TABLE child_passcodes ADD COLUMN IF NOT EXISTS salt TEXT;

-- Step 2: Update existing records with a default salt (for backward compatibility)
-- Note: This will make existing passcodes invalid, but ensures security going forward
UPDATE child_passcodes 
SET salt = 'legacy_salt_' || id::text 
WHERE salt IS NULL;

-- Step 3: Make salt column NOT NULL for new records
ALTER TABLE child_passcodes ALTER COLUMN salt SET NOT NULL;

-- Step 4: Verify the changes
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'child_passcodes' 
AND column_name = 'salt';

-- Step 5: Show sample data
SELECT 
    id,
    user_account_id,
    child_device_id,
    hashed_passcode,
    salt,
    created_at,
    updated_at
FROM child_passcodes 
LIMIT 3;
