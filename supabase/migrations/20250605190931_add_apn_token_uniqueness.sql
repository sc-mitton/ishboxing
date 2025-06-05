-- Add unique constraint for user_id and device_id combination
ALTER TABLE apn_tokens
ADD CONSTRAINT apn_tokens_user_device_unique UNIQUE (user_id, device_id);

-- Drop the existing unique constraint on token since we want to allow the same token
-- to be used by different users/devices
ALTER TABLE apn_tokens
DROP CONSTRAINT IF EXISTS apn_tokens_token_key;
