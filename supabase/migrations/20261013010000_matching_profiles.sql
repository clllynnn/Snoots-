-- F03: one atomic four-section submission per dog. Edits affect recommendations
-- only at the next 06:00 Asia/Taipei candidate batch.
create table if not exists public.dog_matching_profiles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    birth_date date not null,
    activity_needs text[] not null check (cardinality(activity_needs) > 0),
    activity_preferences text[] not null check (cardinality(activity_preferences) > 0),
    activity_free_text text not null default '',
    activity_keywords text[] not null default '{}',
    meeting_environments text[] not null default '{}',
    first_meeting_pace text not null check (first_meeting_pace in (
        '先保持距離平行散步', '遠處觀察後逐步靠近', '雙方放鬆時短暫打招呼'
    )),
    interaction_scenario text,
    interaction_features text[] not null default '{}',
    health_answers jsonb not null default '{}'::jsonb,
    effective_at timestamptz not null,
    profile_version integer not null default 1,
    submitted_at timestamptz not null default now(),
    constraint no_preference_is_exclusive check (
        not ('沒有特別偏好' = any(activity_preferences))
        or cardinality(activity_preferences) = 1
    ),
    constraint no_special_need_is_exclusive check (
        not ('無特殊需求' = any(activity_needs))
        or cardinality(activity_needs) = 1
    )
);

create table if not exists public.dog_matching_profile_versions (
    user_id uuid not null references auth.users(id) on delete cascade,
    profile_version integer not null,
    effective_at timestamptz not null,
    submitted_at timestamptz not null,
    profile_data jsonb not null,
    primary key (user_id, profile_version)
);

create index if not exists matching_profile_versions_effective_idx
on public.dog_matching_profile_versions (user_id, effective_at desc);

alter table public.dog_matching_profiles enable row level security;
alter table public.dog_matching_profile_versions enable row level security;

create policy matching_self_read on public.dog_matching_profiles for select to authenticated
using (user_id = (select auth.uid()));
create policy matching_self_insert on public.dog_matching_profiles for insert to authenticated
with check (user_id = (select auth.uid()));
create policy matching_self_update on public.dog_matching_profiles for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy matching_version_self_read on public.dog_matching_profile_versions for select to authenticated
using (user_id = (select auth.uid()));

grant select, insert, update on public.dog_matching_profiles to authenticated;
grant select on public.dog_matching_profile_versions to authenticated;

create or replace function public.stamp_matching_profile()
returns trigger language plpgsql set search_path = public, pg_temp as $$
declare
    v_local timestamp := now() at time zone 'Asia/Taipei';
    v_next_local timestamp;
begin
    if not exists (select 1 from public.dog_profiles where user_id = new.user_id) then
        raise exception 'A completed dog registration is required';
    end if;
    v_next_local := date_trunc('day', v_local) + interval '6 hours';
    if v_local >= v_next_local then
        v_next_local := v_next_local + interval '1 day';
    end if;
    new.effective_at := v_next_local at time zone 'Asia/Taipei';
    new.submitted_at := now();
    new.profile_version := case when tg_op = 'UPDATE' then old.profile_version + 1 else 1 end;
    return new;
end;
$$;

create or replace function public.archive_matching_profile()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
    insert into public.dog_matching_profile_versions (
        user_id, profile_version, effective_at, submitted_at, profile_data
    ) values (
        new.user_id, new.profile_version, new.effective_at, new.submitted_at,
        to_jsonb(new) - 'user_id' - 'effective_at' - 'profile_version' - 'submitted_at'
    );
    return new;
end;
$$;

create trigger stamp_matching_profile_before_write
before insert or update on public.dog_matching_profiles
for each row execute function public.stamp_matching_profile();

create trigger archive_matching_profile_after_write
after insert or update on public.dog_matching_profiles
for each row execute function public.archive_matching_profile();
