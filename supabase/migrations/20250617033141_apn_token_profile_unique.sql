-- Add unique constraint for profile_id in apn_tokens table
ALTER TABLE apn_tokens
ADD CONSTRAINT apn_tokens_profile_id_unique UNIQUE (profile_id);
