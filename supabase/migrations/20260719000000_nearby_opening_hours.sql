drop function if exists public.nearby_places(double precision, double precision, text, text[], integer);

create function public.nearby_places(
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
    opening_hours jsonb,
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
        p.opening_hours,
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
