create table public.profiles (
  id uuid not null references auth.users on delete cascade,
  username text,
  primary key (id)
);

alter table public.profiles enable row level security;

-- inserts a row into public.profiles
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id)
  values (new.id);
  return new;
end;
$$;

-- trigger the function every time a user is created
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- updates the username when the user is updated
create function public.handle_update_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  update public.profiles
  set username = new.raw_user_meta_data->>'username'
  where id = new.id;
  return new;
end;
$$;

-- trigger the function every time a user is updated
create trigger on_auth_user_updated
  after update on auth.users
  for each row execute procedure public.handle_update_user();

-- Policy to allow users to update their own profiles
create policy "Users can update their own profiles"
on profiles for update
to authenticated
using ( (select auth.uid()) = id )
with check ( (select auth.uid()) = id );

create policy "Users can select all profiles"
on profiles for select
to authenticated
using ( true );
