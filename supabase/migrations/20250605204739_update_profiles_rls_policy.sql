-- Remove old policy
drop policy "Users can update their own profiles" on profiles;

-- Create new policy
create policy "Users can update their own profiles"
on profiles for update
to authenticated
using ( (select auth.uid()) = id )
with check ( (select auth.uid()) = id );
