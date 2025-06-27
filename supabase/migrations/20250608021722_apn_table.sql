-- Create apn_tokens table to store Apple Push Notification tokens
CREATE TABLE IF NOT EXISTS apn_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(token),
    UNIQUE(profile_id)
);

-- Add unique constraint for profile_id and device_id combination
ALTER TABLE apn_tokens
ADD CONSTRAINT apn_tokens_user_device_unique UNIQUE (profile_id, device_id);

-- Create new index for faster lookups
CREATE INDEX idx_apn_tokens_profile_id ON apn_tokens(profile_id);

-- Add RLS policies
ALTER TABLE apn_tokens ENABLE ROW LEVEL SECURITY;

-- Create new policy that only allows access from the service role
CREATE POLICY "Allow service role can access APN tokens"
    ON apn_tokens
    AS PERMISSIVE
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Enable full access for users based on profile_id"
    ON apn_tokens
    AS PERMISSIVE
    FOR ALL
    TO authenticated
    USING (auth.uid() = profile_id)
    WITH CHECK (auth.uid() = profile_id);


-- Create trigger function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_apn_tokens_updated_at
    BEFORE UPDATE ON apn_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
