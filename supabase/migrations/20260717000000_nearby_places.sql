create extension if not exists postgis with schema extensions;

create table public.places (
    id text primary key,
    source_id integer,
    category text not null check (category in (
        'dog_meetup',
        'pet_friendly_restaurant',
        'pet_friendly_park',
        'animal_hospital'
    )),
    name text not null check (length(trim(name)) > 0),
    area text,
    address text,
    latitude double precision check (latitude between -90 and 90),
    longitude double precision check (longitude between -180 and 180),
    location extensions.geography(point, 4326),
    apple_maps_url text,
    website_url text,
    source_url text,
    policy_summary text,
    dog_access_label text check (dog_access_label in (
        'indoor_ok',
        'outdoor_only',
        'carrier_required',
        'restrictions_apply'
    )),
    opening_hours jsonb not null default '{}'::jsonb,
    timezone text not null default 'Asia/Taipei',
    verification_level text not null default 'needs_reconfirmation' check (verification_level in (
        'venue_confirmed',
        'community_confirmed',
        'needs_reconfirmation'
    )),
    verified_at timestamptz,
    published boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (category, source_id),
    check (
        not published or (
            latitude is not null
            and longitude is not null
            and source_url is not null
            and length(trim(source_url)) > 0
            and verified_at is not null
            and dog_access_label is not null
            and policy_summary is not null
            and length(trim(policy_summary)) > 0
        )
    )
);

create table public.filter_options (
    id text primary key,
    category text not null check (category in (
        'dog_meetup',
        'pet_friendly_restaurant',
        'pet_friendly_park',
        'animal_hospital'
    )),
    title_zh_hant text not null,
    title_en text not null,
    display_order integer not null,
    is_active boolean not null default true,
    unique (category, display_order)
);

create table public.place_filters (
    place_id text not null references public.places(id) on delete cascade,
    filter_id text not null references public.filter_options(id) on delete restrict,
    source_url text not null,
    confirmed_at timestamptz,
    verification_level text not null default 'needs_reconfirmation' check (verification_level in (
        'venue_confirmed',
        'community_confirmed',
        'needs_reconfirmation'
    )),
    created_at timestamptz not null default now(),
    primary key (place_id, filter_id)
);

create table public.saved_places (
    user_id uuid not null references auth.users(id) on delete cascade,
    place_id text not null references public.places(id) on delete cascade,
    list_name text not null default 'want_to_visit',
    created_at timestamptz not null default now(),
    primary key (user_id, place_id, list_name)
);

create table public.user_feedback (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    place_id text not null references public.places(id) on delete cascade,
    action text not null check (action in (
        'confirm',
        'report_change',
        'add_condition',
        'mark_closed'
    )),
    detail text,
    status text not null default 'pending' check (status in ('pending', 'reviewed', 'rejected')),
    created_at timestamptz not null default now(),
    reviewed_at timestamptz
);

create or replace function public.sync_place_location()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
    if new.latitude is null or new.longitude is null then
        new.location := null;
    else
        new.location := extensions.st_setsrid(
            extensions.st_makepoint(new.longitude, new.latitude),
            4326
        )::extensions.geography;
    end if;
    new.updated_at := now();
    return new;
end;
$$;

create trigger places_sync_location
before insert or update of latitude, longitude on public.places
for each row execute function public.sync_place_location();

create index places_location_gist on public.places using gist (location);
create index places_published_category_idx on public.places (published, category);
create index place_filters_filter_place_idx on public.place_filters (filter_id, place_id);
create index user_feedback_status_idx on public.user_feedback (status, created_at);

alter table public.places enable row level security;
alter table public.filter_options enable row level security;
alter table public.place_filters enable row level security;
alter table public.saved_places enable row level security;
alter table public.user_feedback enable row level security;

create policy "published places are readable"
on public.places for select
to anon, authenticated
using (published);

create policy "active filter options are readable"
on public.filter_options for select
to anon, authenticated
using (is_active);

create policy "filters of published places are readable"
on public.place_filters for select
to anon, authenticated
using (
    exists (
        select 1
        from public.places
        where places.id = place_filters.place_id
          and places.published
    )
);

create policy "users can read their saved places"
on public.saved_places for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "users can save places for themselves"
on public.saved_places for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "users can remove their saved places"
on public.saved_places for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy "users can read their feedback"
on public.user_feedback for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "users can submit feedback"
on public.user_feedback for insert
to authenticated
with check (
    (select auth.uid()) = user_id
    and status = 'pending'
    and reviewed_at is null
);

create or replace function public.nearby_places(
    p_latitude double precision,
    p_longitude double precision,
    p_category text default null,
    p_filter_ids text[] default array[]::text[],
    p_limit integer default 100
)
returns table (
    id text,
    category text,
    name text,
    area text,
    address text,
    latitude double precision,
    longitude double precision,
    apple_maps_url text,
    website_url text,
    source_url text,
    policy_summary text,
    dog_access_label text,
    verification_level text,
    verified_at timestamptz,
    filter_ids text[],
    distance_meters double precision
)
language sql
stable
security invoker
set search_path = ''
as $$
    select
        p.id,
        p.category,
        p.name,
        p.area,
        p.address,
        p.latitude,
        p.longitude,
        p.apple_maps_url,
        p.website_url,
        p.source_url,
        p.policy_summary,
        p.dog_access_label,
        p.verification_level,
        p.verified_at,
        filters.ids,
        extensions.st_distance(
            p.location,
            extensions.st_setsrid(
                extensions.st_makepoint(p_longitude, p_latitude),
                4326
            )::extensions.geography
        ) as distance_meters
    from public.places p
    cross join lateral (
        select coalesce(array_agg(pf.filter_id order by pf.filter_id), array[]::text[]) as ids
        from public.place_filters pf
        where pf.place_id = p.id
    ) filters
    where p.published
      and p.location is not null
      and (p_category is null or p.category = p_category)
      and coalesce(p_filter_ids, array[]::text[]) <@ filters.ids
    order by p.location operator(extensions.<->) extensions.st_setsrid(
        extensions.st_makepoint(p_longitude, p_latitude),
        4326
    )::extensions.geography
    limit least(greatest(coalesce(p_limit, 100), 1), 200);
$$;

revoke all on function public.nearby_places(double precision, double precision, text, text[], integer) from public;
grant execute on function public.nearby_places(double precision, double precision, text, text[], integer) to anon, authenticated;

grant select on public.places, public.filter_options, public.place_filters to anon, authenticated;
grant select, insert, delete on public.saved_places to authenticated;
grant select, insert on public.user_feedback to authenticated;
grant usage, select on sequence public.user_feedback_id_seq to authenticated;

grant all on public.places, public.filter_options, public.place_filters,
    public.saved_places, public.user_feedback to service_role;
grant all on sequence public.user_feedback_id_seq to service_role;
