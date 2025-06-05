-- Create new policy
create policy "Users can select their own profiles"
on profiles for select
to authenticated
using ( (select auth.uid()) = id );
