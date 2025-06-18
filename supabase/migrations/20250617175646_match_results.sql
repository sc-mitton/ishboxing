create table public.match_results (
  id uuid not null default uuid_generate_v4(),
  winner uuid not null references public.profiles(id) on delete cascade,
  loser uuid not null references public.profiles(id) on delete cascade,
  match_id bigint not null references public.matches on delete cascade,
  winner_score integer not null,
  loser_score integer not null,
  created_at timestamp with time zone not null default now(),
  primary key (id, match_id)
);

alter table public.match_results enable row level security;
