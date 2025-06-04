
create policy "meeting owners can add users"
on "public"."meeting_users"
for insert
with check (
  exists (
    select 1
    from meeting_users as mu
    where mu.user_id = auth.uid()
      and mu.meeting_topic = meeting_users.meeting_topic
      and mu.is_owner = true
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
      meeting_users
    where
      user_id = (select auth.uid())
      and meeting_topic = (select realtime.topic())
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
      meeting_users
    where
      user_id = (select auth.uid())
      and meeting_topic = (select realtime.topic())
      and realtime.messages.extension in ('broadcast')
  )
);
