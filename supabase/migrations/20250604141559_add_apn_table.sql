-- Create apn_tokens table to store Apple Push Notification tokens
CREATE TABLE IF NOT EXISTS apn_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(token)
);

-- Add RLS policies
ALTER TABLE apn_tokens ENABLE ROW LEVEL SECURITY;

-- Allow users to view their own tokens
CREATE POLICY "Users can view their own APN tokens"
    ON apn_tokens
    FOR SELECT
    USING (auth.uid() = user_id);

-- Allow users to insert their own tokens
CREATE POLICY "Users can insert their own APN tokens"
    ON apn_tokens
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own tokens
CREATE POLICY "Users can update their own APN tokens"
    ON apn_tokens
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own tokens
CREATE POLICY "Users can delete their own APN tokens"
    ON apn_tokens
    FOR DELETE
    USING (auth.uid() = user_id);

-- Create index for faster lookups
CREATE INDEX idx_apn_tokens_user_id ON apn_tokens(user_id);

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
