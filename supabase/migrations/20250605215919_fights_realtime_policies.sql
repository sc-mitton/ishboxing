create policy "match owners can add users"
on "public"."match_users"
for insert
with check (
  exists (
    select 1
    from match_users as mu
    where mu.user_id = auth.uid()
      and mu.match_topic = match_users.match_topic
      and fu.is_owner = true
  )
);

create policy "authenticated can send broadcast on topic"
on "realtime"."messages"
for insert
to authenticated
with check (
  exists (
    select
      user_id
    from
      match_users
    where
      user_id = (select auth.uid())
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
      user_id
    from
      match_users
    where
      user_id = (select auth.uid())
      and match_topic = (select realtime.topic())
      and realtime.messages.extension in ('broadcast')
  )
);
