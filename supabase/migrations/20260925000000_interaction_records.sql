-- Each offline meetup is an event record. Post-event feedback must never mutate dog_profiles.
create table if not exists public.interaction_records (
    id uuid primary key default gen_random_uuid(),
    initiator_user_id uuid not null references auth.users(id) on delete cascade,
    initiator_dog_id uuid not null,
    partner_user_id uuid not null references auth.users(id) on delete cascade,
    partner_dog_id uuid not null,
    meetup_at timestamptz not null,
    location_name text,
    outcome text not null default 'completed' check (outcome in ('completed', 'left_early', 'cancelled')),
    observed_signals text[] not null default '{}',
    feedback_tags text[] not null default '{}',
    feedback_note text,
    mutual_rebook_choice text check (mutual_rebook_choice in ('yes', 'keep_as_is', null)),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists interaction_records_dogs_idx
    on public.interaction_records (initiator_dog_id, partner_dog_id, meetup_at desc);

alter table public.interaction_records enable row level security;

create policy "participants can read their interaction records"
on public.interaction_records for select
to authenticated
using ((select auth.uid()) in (initiator_user_id, partner_user_id));

create policy "participants can create interaction records"
on public.interaction_records for insert
to authenticated
with check ((select auth.uid()) in (initiator_user_id, partner_user_id));

create policy "participants can update their interaction records"
on public.interaction_records for update
to authenticated
using ((select auth.uid()) in (initiator_user_id, partner_user_id))
with check ((select auth.uid()) in (initiator_user_id, partner_user_id));
