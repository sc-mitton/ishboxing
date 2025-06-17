create table public.match_results (
  id uuid not null references auth.users on delete cascade,
  winner uuid not null references auth.users on delete cascade,
  match_id uuid not null references public.matches on delete cascade,
  winner_score integer not null,
  loser_score integer not null,
  created_at timestamp with time zone not null default now(),
  primary key (id, match_id)
);

alter table public.match_results enable row level security;
