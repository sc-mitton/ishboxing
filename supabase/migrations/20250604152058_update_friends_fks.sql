-- Drop existing foreign key constraints
ALTER TABLE public.friends
    DROP CONSTRAINT IF EXISTS friends_user_id_fkey,
    DROP CONSTRAINT IF EXISTS friends_friend_id_fkey;

-- Add new foreign key constraints pointing to profiles
ALTER TABLE public.friends
    ADD CONSTRAINT friends_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES public.profiles(id)
    ON DELETE CASCADE,
    ADD CONSTRAINT friends_friend_id_fkey
    FOREIGN KEY (friend_id)
    REFERENCES public.profiles(id)
    ON DELETE CASCADE;
