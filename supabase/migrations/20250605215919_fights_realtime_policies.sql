create policy "fight owners can add users"
on "public"."fight_users"
for insert
with check (
  exists (
    select 1
    from fight_users as fu
    where fu.user_id = auth.uid()
      and fu.fight_topic = fight_users.fight_topic
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
      fight_users
    where
      user_id = (select auth.uid())
      and fight_topic = (select realtime.topic())
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
      fight_users
    where
      user_id = (select auth.uid())
      and fight_topic = (select realtime.topic())
      and realtime.messages.extension in ('broadcast')
  )
);
