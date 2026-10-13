-- F01/F02: a signed-in person owns exactly one dog in the first TestFlight release.
create table if not exists public.owner_profiles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    nickname text not null check (length(btrim(nickname)) between 1 and 60),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.dog_profiles (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null unique references auth.users(id) on delete cascade,
    name text not null check (length(btrim(name)) between 1 and 60),
    breed text not null check (length(btrim(breed)) between 1 and 100),
    breed_mapping_status text not null default 'mapped' check (breed_mapping_status in ('mapped', 'pending')),
    size text not null check (size in ('small', 'medium', 'large')),
    sex text not null check (sex in ('male', 'female')),
    is_neutered boolean not null,
    social_style text not null check (social_style in (
        'friendly', 'observe_then_interact', 'fearful_approach',
        'fearful_avoid', 'bark_or_growl'
    )),
    photo_path text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.pending_breed_mappings (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    original_label text not null check (length(btrim(original_label)) between 1 and 100),
    status text not null default 'pending' check (status in ('pending', 'mapped', 'ignored')),
    created_at timestamptz not null default now()
);

alter table public.owner_profiles enable row level security;
alter table public.dog_profiles enable row level security;
alter table public.pending_breed_mappings enable row level security;

create policy owner_self_read on public.owner_profiles for select to authenticated
using (user_id = (select auth.uid()));
create policy owner_self_insert on public.owner_profiles for insert to authenticated
with check (user_id = (select auth.uid()));
create policy owner_self_update on public.owner_profiles for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy dog_self_read on public.dog_profiles for select to authenticated
using (user_id = (select auth.uid()));
create policy dog_self_insert on public.dog_profiles for insert to authenticated
with check (user_id = (select auth.uid()));
create policy dog_self_update on public.dog_profiles for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy breed_request_self_read on public.pending_breed_mappings for select to authenticated
using (user_id = (select auth.uid()));
create policy breed_request_self_insert on public.pending_breed_mappings for insert to authenticated
with check (user_id = (select auth.uid()));

grant select, insert, update on public.owner_profiles, public.dog_profiles to authenticated;
grant select, insert on public.pending_breed_mappings to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('dog-photos', 'dog-photos', false, 10485760, array['image/jpeg'])
on conflict (id) do nothing;

create policy dog_photo_owner_insert on storage.objects for insert to authenticated
with check (
    bucket_id = 'dog-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
);
create policy dog_photo_owner_read on storage.objects for select to authenticated
using (
    bucket_id = 'dog-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
);
create policy dog_photo_owner_delete on storage.objects for delete to authenticated
using (
    bucket_id = 'dog-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- One database transaction creates the owner and dog. No partial profile is visible.
create or replace function public.complete_registration(
    p_nickname text,
    p_dog_name text,
    p_breed text,
    p_other_breed text,
    p_size text,
    p_sex text,
    p_is_neutered boolean,
    p_social_style text,
    p_photo_path text
) returns void language plpgsql security invoker set search_path = public, storage, pg_temp as $$
declare
    v_user_id uuid := auth.uid();
begin
    if v_user_id is null then
        raise exception 'Authentication required';
    end if;
    if exists (select 1 from public.dog_profiles where user_id = v_user_id) then
        raise exception 'A dog profile already exists for this account';
    end if;
    if p_photo_path not like v_user_id::text || '/%' or not exists (
        select 1 from storage.objects where bucket_id = 'dog-photos' and name = p_photo_path
    ) then
        raise exception 'A valid uploaded dog photo is required';
    end if;
    if p_breed = '其他' and nullif(btrim(p_other_breed), '') is null then
        raise exception 'Other breed name is required';
    end if;
    insert into public.owner_profiles (user_id, nickname)
    values (v_user_id, btrim(p_nickname));
    insert into public.dog_profiles (
        user_id, name, breed, breed_mapping_status, size, sex, is_neutered, social_style, photo_path
    ) values (
        v_user_id, btrim(p_dog_name),
        case when p_breed = '其他' then btrim(p_other_breed) else btrim(p_breed) end,
        case when p_breed = '其他' then 'pending' else 'mapped' end,
        p_size, p_sex, p_is_neutered, p_social_style, p_photo_path
    );
    if p_breed = '其他' then
        insert into public.pending_breed_mappings (user_id, original_label)
        values (v_user_id, btrim(p_other_breed));
    end if;
end;
$$;

revoke all on function public.complete_registration(text,text,text,text,text,text,boolean,text,text) from public;
grant execute on function public.complete_registration(text,text,text,text,text,text,boolean,text,text) to authenticated;
