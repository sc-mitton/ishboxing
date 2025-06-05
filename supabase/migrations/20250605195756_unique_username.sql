-- Create a unique index on the username column
CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_idx ON profiles (username);

-- Add a unique constraint to ensure data integrity
ALTER TABLE profiles ADD CONSTRAINT profiles_username_unique UNIQUE (username);
