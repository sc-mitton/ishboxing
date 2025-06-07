create policy "authenticated can send broadcast on topic"
on "realtime"."messages"
for insert
to authenticated
with check (
  exists (
    select
      profile_id
    from
      match_users
    where
      profile_id = (select auth.uid())
      and match_topic = (select realtime.topic())
      and realtime.messages.extension in ('broadcast')
  )
);

create policy "authenticated can receive broadcast"
on "realtime"."messages"
for select
to authenticated
using (
exists (
    select
      profile_id
    from
      match_users
    where
      profile_id = (select auth.uid())
      and match_topic = (select realtime.topic())
      and realtime.messages.extension in ('broadcast')
  )
);

-- Only authenticated users can create matches
create policy "Enable insert for authenticated users only"
on "public"."matches"
as PERMISSIVE
for INSERT
to authenticated
with check (true);
