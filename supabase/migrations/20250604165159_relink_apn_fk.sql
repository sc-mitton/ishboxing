-- Drop existing foreign key constraint from apn_tokens table
ALTER TABLE public.apn_tokens DROP CONSTRAINT IF EXISTS apn_tokens_user_id_fkey;

-- Add new foreign key constraint linking to profiles table
ALTER TABLE public.apn_tokens
  ADD CONSTRAINT apn_tokens_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES public.profiles(id)
  ON DELETE CASCADE;

