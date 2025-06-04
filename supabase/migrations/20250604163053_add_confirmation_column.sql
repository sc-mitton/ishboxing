-- Add confirmation column to friends table
ALTER TABLE public.friends
    ADD COLUMN confirmed BOOLEAN DEFAULT NULL;

-- Policy to allow users to update confirmation status of their friendships
CREATE POLICY "Users can update confirmation status of their friendships"
    ON public.friends
    FOR UPDATE
    USING (auth.uid() = friend_id)
    WITH CHECK (auth.uid() = friend_id AND (confirmed IS NOT NULL));
