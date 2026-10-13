-- F12–F18 / D05. Apply after account_profiles and matching_profiles.
-- All mutations are RPC-only and authenticate auth.uid(), never a client-supplied identity.
begin;
create table public.meetup_testers (
    user_id uuid primary key references auth.users(id) on delete cascade,
    is_demo boolean not null default false,
    enabled boolean not null default true
);
create table public.meetup_events (
    id uuid primary key,
    host_id uuid not null references auth.users(id),
    title text not null check (length(btrim(title)) between 1 and 80),
    start_at timestamptz not null,
    deadline timestamptz not null check (deadline <= start_at),
    location text not null check (length(btrim(location)) between 1 and 200),
    navigation_url text not null default '',
    purpose text not null check (length(btrim(purpose)) between 1 and 2000),
    pace text not null,
    capacity int not null check (capacity between 2 and 30),
    allowed_sizes text[] not null default '{}',
    venue_rules text not null default '' check (length(venue_rules) <= 2000),
    extra_equipment text not null default '' check (length(extra_equipment) <= 1000),
    announcement text not null default '' check (length(announcement) <= 2000),
    status text not null default 'active' check (status in ('active','ended','cancelled','archived')),
    ended_at timestamptz,
    archived_at timestamptz,
    invite_code text unique not null default replace(gen_random_uuid()::text,'-',''),
    version int not null default 1,
    info_version int not null default 1,
    equipment_version int not null default 1,
    rules_version int not null default 1,
    created_at timestamptz not null default now(),
    check (allowed_sizes <@ array['small','medium','large']),
    check (navigation_url = '' or navigation_url ~ '^https://[^[:space:]]+$')
);
create table public.meetup_applications (
    meetup_id uuid not null references public.meetup_events(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    status text not null check (status in ('pending','approved','rejected','left')),
    shared_dog jsonb not null default '{}',
    consent_fields text[] not null default '{}',
    consent_at timestamptz,
    request_id uuid not null,
    muted boolean not null default false,
    last_read_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (meetup_id,user_id)
);
create table public.meetup_confirmations (
    meetup_id uuid not null references public.meetup_events(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    section text not null check (section in ('info','equipment','rules')),
    version int not null,
    confirmed_at timestamptz not null default now(),
    primary key (meetup_id,user_id,section)
);
create table public.meetup_messages (
    id uuid primary key,
    meetup_id uuid not null references public.meetup_events(id) on delete cascade,
    sender_id uuid references auth.users(id) on delete set null,
    sender_name text not null,
    body text not null check (length(btrim(body)) between 1 and 2000),
    system_key text,
    created_at timestamptz not null default now(),
    unique(meetup_id,system_key)
);
create index meetup_messages_order on public.meetup_messages(meetup_id,created_at,id);
create index meetup_applications_person on public.meetup_applications(user_id);
create table public.meetup_end_requests (
    id uuid primary key,
    meetup_id uuid not null references public.meetup_events(id) on delete cascade,
    expires_at timestamptz not null default now() + interval '48 hours',
    closed_at timestamptz,
    created_at timestamptz not null default now()
);
create unique index meetup_one_end_request on public.meetup_end_requests(meetup_id) where closed_at is null;
create table public.meetup_end_votes (
    request_id uuid not null references public.meetup_end_requests(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    primary key(request_id,user_id)
);
create table public.meetup_reports (
    meetup_id uuid not null references public.meetup_events(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    reason text not null check (length(btrim(reason)) between 1 and 1000),
    created_at timestamptz not null default now(),
    primary key(meetup_id,user_id)
);
create table public.meetup_review_cases (
    meetup_id uuid primary key references public.meetup_events(id) on delete cascade,
    status text not null default 'pending' check(status in ('pending','dismissed','ended')),
    created_at timestamptz not null default now(),
    reviewed_at timestamptz,
    reviewer text,
    decision_note text
);

-- No direct client access: SECURITY DEFINER RPCs return only role-appropriate projections.
do $$ declare t text; begin
    foreach t in array array['meetup_testers','meetup_events','meetup_applications','meetup_confirmations',
        'meetup_messages','meetup_end_requests','meetup_end_votes','meetup_reports','meetup_review_cases'] loop
        execute format('alter table public.%I enable row level security',t);
        execute format('revoke all on public.%I from anon, authenticated',t);
    end loop;
end $$;

create function public.meetup_has_access(p_id uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
    select exists(select 1 from meetup_events e join meetup_applications a on a.meetup_id=e.id
        join meetup_testers t on t.user_id=a.user_id
        where e.id=p_id and a.user_id=p_user and t.enabled and a.status='approved'
        and (e.status='active' or (e.status='ended' and now()<e.ended_at+interval '14 days')));
$$;

-- Safe to run every minute: unique keys make reminders idempotent, and request-time
-- permission checks revoke access at the precise deadline even if scheduling is delayed.
create function public.maintain_meetup_lifecycle()
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
    update meetup_end_requests set closed_at=now() where closed_at is null and expires_at<=now();
    insert into meetup_messages(id,meetup_id,sender_name,body,system_key,created_at)
    select gen_random_uuid(), e.id, '系統',
        '這個狗聚群組將於 '||to_char((e.ended_at+interval '14 days') at time zone 'Asia/Taipei','YYYY/MM/DD HH24:MI')||
        '（台灣時間）關閉，請把握時間聯絡想保持聯繫的狗友。既有的一對一聊天室仍可使用。',
        'expiry-'||n.day_offset, e.ended_at + make_interval(days=>n.day_offset)
    from meetup_events e cross join (values(0),(11),(13)) n(day_offset)
    where e.status in ('ended','archived') and e.ended_at is not null
        and e.ended_at+make_interval(days=>n.day_offset)<=now()
    on conflict(meetup_id,system_key) do nothing;
    update meetup_events set status='archived',archived_at=now()
    where status='ended' and ended_at+interval '14 days'<=now();
end;
$$;

create function public.meetup_snapshot(p_selected uuid default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare u uuid:=auth.uid(); result jsonb;
begin
    if u is null or not exists(select 1 from meetup_testers where user_id=u and enabled) then
        raise exception '尚未加入本次測試名單，請聯絡團隊。';
    end if;
    perform maintain_meetup_lifecycle();
    select coalesce(jsonb_agg(row_data order by start_at,id),'[]') into result from (
        select e.id,e.start_at,jsonb_build_object(
            'id',e.id,'hostID',e.host_id,'hostName',o.nickname,'title',e.title,
            'startAt',extract(epoch from e.start_at),'deadline',extract(epoch from e.deadline),
            'location',e.location,'navigationURL',e.navigation_url,'purpose',e.purpose,'pace',e.pace,
            'capacity',e.capacity,'allowedSizes',to_jsonb(e.allowed_sizes),'venueRules',e.venue_rules,
            'extraEquipment',e.extra_equipment,'announcement',e.announcement,'status',e.status,
            'endedAt',extract(epoch from e.ended_at),'inviteCode',e.invite_code,
            'version',e.version,'infoVersion',e.info_version,'equipmentVersion',e.equipment_version,
            'rulesVersion',e.rules_version,'myStatus',mine.status,'muted',coalesce(mine.muted,false),
            'unread',case when meetup_has_access(e.id,u) then (select count(*) from meetup_messages
                where meetup_id=e.id and created_at>mine.last_read_at and sender_id is distinct from u) else 0 end,
            'lastMessage',case when meetup_has_access(e.id,u) then (select body from meetup_messages where meetup_id=e.id order by created_at desc,id desc limit 1) end,
            'confirmations',coalesce((select jsonb_object_agg(section,version) from meetup_confirmations where meetup_id=e.id and user_id=u),'{}'),
            'members',coalesce((select jsonb_agg(jsonb_build_object(
                'userID',a.user_id,'nickname',op.nickname,'status',a.status,
                'requestID',case when e.host_id=u then a.request_id end,
                'dog',case when e.host_id=u and meetup_has_access(e.id,u) then a.shared_dog
                    else jsonb_strip_nulls(jsonb_build_object('name',d.name)) end) order by a.updated_at)
                from meetup_applications a join owner_profiles op on op.user_id=a.user_id
                join dog_profiles d on d.user_id=a.user_id
                where a.meetup_id=e.id and (a.status='approved' or (e.host_id=u and meetup_has_access(e.id,u)))),'[]'),
            'messages',case when meetup_has_access(e.id,u) and e.id=p_selected then coalesce((
                select jsonb_agg(jsonb_build_object('id',m.id,'senderID',m.sender_id,'senderName',m.sender_name,
                    'text',m.body,'createdAt',extract(epoch from m.created_at)) order by m.created_at,m.id)
                from (select * from meetup_messages where meetup_id=e.id) m),'[]') else '[]'::jsonb end,
            'endApplication',case when meetup_has_access(e.id,u) then (
                select jsonb_build_object('id',r.id,'expiresAt',extract(epoch from r.expires_at),
                    'confirmedBy',coalesce((select jsonb_agg(v.user_id) from meetup_end_votes v
                        join meetup_applications a on a.user_id=v.user_id and a.meetup_id=e.id
                        where v.request_id=r.id and a.status='approved' and v.user_id<>e.host_id),'[]'))
                from meetup_end_requests r where r.meetup_id=e.id and r.closed_at is null and r.expires_at>now() limit 1) end
        ) row_data
        from meetup_events e join owner_profiles o on o.user_id=e.host_id
        join meetup_testers host_t on host_t.user_id=e.host_id and host_t.enabled
        join meetup_testers self_t on self_t.user_id=u and self_t.is_demo=host_t.is_demo
        left join meetup_applications mine on mine.meetup_id=e.id and mine.user_id=u
        where (e.status='active' or e.host_id=u or mine.user_id is not null)
    ) rows;
    return jsonb_build_object('meetups',result,'selectedID',p_selected);
end;
$$;

create function public.meetup_command(p_action text,p_meetup_id uuid,p_payload jsonb default '{}')
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
    u uuid:=auth.uid(); e meetup_events%rowtype; a meetup_applications%rowtype;
    d dog_profiles%rowtype; r meetup_end_requests%rowtype; fields text[];
    shared jsonb:='{}'; target uuid; count_members int; confirmed int; nickname text;
    new_info boolean; new_rules boolean; new_equipment boolean; v int;
begin
    if u is null or not exists(select 1 from meetup_testers where user_id=u and enabled) then
        raise exception '尚未加入本次測試名單，請聯絡團隊。';
    end if;
    select * into d from dog_profiles where user_id=u;
    if not found then raise exception '請先建立自己的狗狗檔案。'; end if;
    perform maintain_meetup_lifecycle();
    if p_action='create' then
        -- A stable ID makes retrying an uncertain network response safe.
        if exists(select 1 from meetup_events where id=p_meetup_id and host_id=u) then
            return meetup_snapshot(p_meetup_id);
        end if;
        insert into meetup_events(id,host_id,title,start_at,deadline,location,navigation_url,purpose,pace,
            capacity,allowed_sizes,venue_rules,extra_equipment,announcement)
        values(p_meetup_id,u,btrim(p_payload->>'title'),to_timestamp((p_payload->>'startAt')::double precision),
            to_timestamp((p_payload->>'deadline')::double precision),btrim(p_payload->>'location'),
            coalesce(p_payload->>'navigationURL',''),btrim(p_payload->>'purpose'),p_payload->>'pace',
            (p_payload->>'capacity')::int,array(select jsonb_array_elements_text(p_payload->'allowedSizes')),
            coalesce(p_payload->>'venueRules',''),coalesce(p_payload->>'extraEquipment',''),coalesce(p_payload->>'announcement',''));
        if (p_payload->>'startAt')::double precision<=extract(epoch from now()) then raise exception '活動開始時間必須在未來。'; end if;
        insert into meetup_applications(meetup_id,user_id,status,request_id)
        values(p_meetup_id,u,'approved',gen_random_uuid());
        return meetup_snapshot(p_meetup_id);
    end if;
    select * into e from meetup_events where id=p_meetup_id for update;
    if not found or not exists(select 1 from meetup_testers h join meetup_testers t on t.user_id=u
        where h.user_id=e.host_id and h.enabled and h.is_demo=t.is_demo) then raise exception '找不到可存取的狗聚。'; end if;
    select * into a from meetup_applications where meetup_id=e.id and user_id=u;
    if p_action='apply' then
        if a.request_id=(p_payload->>'requestID')::uuid then return meetup_snapshot(e.id); end if;
        if a.status in ('approved','pending') then raise exception '已報名，請查看審核結果。'; end if;
        select count(*) into count_members from meetup_applications where meetup_id=e.id and status='approved';
        if e.status<>'active' or now()>=e.deadline or count_members>=e.capacity then raise exception '活動已截止、額滿或結束。'; end if;
        if cardinality(e.allowed_sizes)>0 and not d.size=any(e.allowed_sizes) then raise exception '狗狗體型不符合明確場地条件。'; end if;
        fields:=array(select jsonb_array_elements_text(coalesce(p_payload->'fields','[]')));
        if not fields <@ array['basic','sex','age','reaction'] then raise exception '不支援的分享欄位。'; end if;
        if cardinality(fields)>0 and not coalesce((p_payload->>'consent')::boolean,false) then raise exception '請先同意帶入資料。'; end if;
        if 'basic'=any(fields) then shared:=shared||jsonb_build_object('name',d.name,'breed',d.breed,'size',d.size,'photoPath',d.photo_path); end if;
        if 'sex'=any(fields) then shared:=shared||jsonb_build_object('sex',d.sex,'neutered',d.is_neutered); end if;
        if 'reaction'=any(fields) then shared:=shared||jsonb_build_object('reaction',d.social_style); end if;
        if 'age'=any(fields) then shared:=shared||jsonb_build_object('age',(select extract(year from age(current_date,birth_date))::int::text||' 歲' from dog_matching_profiles where user_id=u)); end if;
        insert into meetup_applications(meetup_id,user_id,status,shared_dog,consent_fields,consent_at,request_id)
        values(e.id,u,'pending',jsonb_strip_nulls(shared),fields,case when cardinality(fields)>0 then now() end,(p_payload->>'requestID')::uuid)
        on conflict(meetup_id,user_id) do update set status='pending',shared_dog=excluded.shared_dog,
            consent_fields=excluded.consent_fields,consent_at=excluded.consent_at,request_id=excluded.request_id,updated_at=now();
    elsif p_action in ('edit','review','announce','requestEnd') then
        if e.host_id<>u or not meetup_has_access(e.id,u) or e.status<>'active' then raise exception '只有該場有效發起人可執行。'; end if;
        if p_action='edit' then
            if e.version<>(p_payload->>'version')::int then raise exception '活動已被更新，請重新載入後編輯。'; end if;
            select count(*) into count_members from meetup_applications where meetup_id=e.id and status='approved';
            if (p_payload->>'capacity')::int<count_members then raise exception '名額不能低於目前核准人數。'; end if;
            new_info:=row(e.title,e.start_at,e.location,e.purpose,e.pace,e.navigation_url,e.announcement)
                is distinct from row(p_payload->>'title',to_timestamp((p_payload->>'startAt')::double precision),p_payload->>'location',p_payload->>'purpose',p_payload->>'pace',p_payload->>'navigationURL',p_payload->>'announcement');
            new_rules:=e.venue_rules is distinct from p_payload->>'venueRules' or e.allowed_sizes is distinct from array(select jsonb_array_elements_text(p_payload->'allowedSizes'));
            new_equipment:=e.extra_equipment is distinct from p_payload->>'extraEquipment';
            update meetup_events set title=btrim(p_payload->>'title'),start_at=to_timestamp((p_payload->>'startAt')::double precision),
                deadline=to_timestamp((p_payload->>'deadline')::double precision),location=btrim(p_payload->>'location'),
                navigation_url=p_payload->>'navigationURL',purpose=btrim(p_payload->>'purpose'),pace=p_payload->>'pace',capacity=(p_payload->>'capacity')::int,
                allowed_sizes=array(select jsonb_array_elements_text(p_payload->'allowedSizes')),venue_rules=p_payload->>'venueRules',
                extra_equipment=p_payload->>'extraEquipment',announcement=p_payload->>'announcement',version=version+1,
                info_version=info_version+new_info::int,rules_version=rules_version+new_rules::int,
                equipment_version=equipment_version+new_equipment::int where id=e.id;
        elsif p_action='review' then
            target:=(p_payload->>'userID')::uuid;
            if target=u or p_payload->>'status' not in ('approved','rejected') then raise exception '審核操作不正確。'; end if;
            select * into a from meetup_applications where meetup_id=e.id and user_id=target;
            if a.status=p_payload->>'status' and a.request_id=(p_payload->>'requestID')::uuid then return meetup_snapshot(e.id); end if;
            if a.status is distinct from 'pending' or a.request_id is distinct from (p_payload->>'requestID')::uuid then raise exception '申請狀態已變更，請重新載入。'; end if;
            select count(*) into count_members from meetup_applications where meetup_id=e.id and status='approved';
            if p_payload->>'status'='approved' and count_members>=e.capacity then raise exception '已額滿。'; end if;
            if p_payload->>'status'='approved' then
                if not exists(select 1 from meetup_testers t where t.user_id=target and t.enabled) then raise exception '申請人目前不在有效測試名單。'; end if;
                if cardinality(e.allowed_sizes)>0 and not exists(select 1 from dog_profiles dog where dog.user_id=target and dog.size=any(e.allowed_sizes)) then raise exception '狗狗體型不符合目前場地條件，請重新確認。'; end if;
            end if;
            update meetup_applications set status=p_payload->>'status',updated_at=now(),last_read_at=now() where meetup_id=e.id and user_id=target;
        elsif p_action='announce' then
            update meetup_events set announcement=p_payload->>'text',version=version+1,info_version=info_version+(announcement is distinct from p_payload->>'text')::int where id=e.id;
        else
            insert into meetup_end_requests(id,meetup_id) values((p_payload->>'requestID')::uuid,e.id)
            on conflict do nothing;
        end if;
    else
        if not meetup_has_access(e.id,u) then raise exception '活動資格或群組存取已失效。'; end if;
        if p_action='send' then
            select op.nickname into nickname from owner_profiles op where op.user_id=u;
            insert into meetup_messages(id,meetup_id,sender_id,sender_name,body)
            values((p_payload->>'messageID')::uuid,e.id,u,nickname,btrim(p_payload->>'text')) on conflict(id) do nothing;
        elsif p_action='read' then
            update meetup_applications set last_read_at=now() where meetup_id=e.id and user_id=u;
        elsif p_action='mute' then
            update meetup_applications set muted=(p_payload->>'muted')::boolean where meetup_id=e.id and user_id=u;
        elsif p_action='leave' then
            if e.host_id=u then raise exception '發起人請使用結束申請。'; end if;
            update meetup_applications set status='left',updated_at=now() where meetup_id=e.id and user_id=u;
        elsif p_action='confirm' then
            v:=case p_payload->>'section' when 'info' then e.info_version when 'equipment' then e.equipment_version when 'rules' then e.rules_version end;
            if v is null or v is distinct from (p_payload->>'version')::int then raise exception '內容已更新，請重新閱讀。'; end if;
            insert into meetup_confirmations(meetup_id,user_id,section,version) values(e.id,u,p_payload->>'section',v)
            on conflict(meetup_id,user_id,section) do update set version=excluded.version,confirmed_at=now();
        elsif p_action='approveEnd' then
            if u=e.host_id then raise exception '發起人不能計入確認人數。'; end if;
            select * into r from meetup_end_requests where id=(p_payload->>'requestID')::uuid and meetup_id=e.id and closed_at is null and expires_at>now();
            if not found then raise exception '結束申請已失效。'; end if;
            insert into meetup_end_votes values(r.id,u) on conflict do nothing;
            select count(*) into confirmed from meetup_end_votes vote join meetup_applications participant
                on participant.user_id=vote.user_id and participant.meetup_id=e.id
                where vote.request_id=r.id and participant.status='approved' and vote.user_id<>e.host_id;
            if confirmed>=2 then
                update meetup_events set status='ended',ended_at=now() where id=e.id and status='active';
                update meetup_end_requests set closed_at=now() where id=r.id;
            end if;
        elsif p_action='report' then
            if u=e.host_id then raise exception '發起人不計入檢舉門檻。'; end if;
            insert into meetup_reports values(e.id,u,btrim(p_payload->>'reason'),now()) on conflict(meetup_id,user_id) do nothing;
            if (select count(*) from meetup_reports where meetup_id=e.id)>=5 then
                insert into meetup_review_cases(meetup_id) values(e.id) on conflict do nothing;
            end if;
        else raise exception '未知操作。'; end if;
    end if;
    return meetup_snapshot(e.id);
end;
$$;

-- Used by F19: call before creating any check-in. Actual phone-touch technology is D04.
create function public.meetup_checkin_eligible(p_meetup_id uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
    select meetup_has_access(p_meetup_id,auth.uid()) and exists(
        select 1 from meetup_events e join meetup_confirmations c on c.meetup_id=e.id
        where e.id=p_meetup_id and e.status='active' and c.user_id=auth.uid()
            and c.section='rules' and c.version=e.rules_version);
$$;

-- Only the current host can read a photo explicitly shared for review. The
-- private bucket stays private; leaving/expiry revokes this grant immediately.
create function public.meetup_can_review_photo(p_path text)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
    select exists(select 1 from meetup_applications a join meetup_events e on e.id=a.meetup_id
        where e.host_id=auth.uid() and meetup_has_access(e.id,auth.uid())
            and a.status in ('pending','approved') and a.consent_at is not null
            and 'basic'=any(a.consent_fields) and a.shared_dog->>'photoPath'=p_path);
$$;
revoke all on function public.meetup_can_review_photo(text) from public,anon;
grant execute on function public.meetup_can_review_photo(text) to authenticated;
create policy meetup_consented_photo_review on storage.objects for select to authenticated
    using (bucket_id='dog-photos' and public.meetup_can_review_photo(name));

-- Backend-only manual review. Recording a case never automatically ends an event.
create function public.review_meetup_case(p_meetup_id uuid,p_end boolean,p_reviewer text,p_note text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
    if nullif(btrim(p_reviewer),'') is null or nullif(btrim(p_note),'') is null then raise exception 'Reviewer and decision note required'; end if;
    perform 1 from meetup_events where id=p_meetup_id for update;
    update meetup_review_cases set status=case when p_end then 'ended' else 'dismissed' end,
        reviewed_at=now(),reviewer=p_reviewer,decision_note=p_note where meetup_id=p_meetup_id and status='pending';
    if not found then raise exception 'No pending review case'; end if;
    if p_end then update meetup_events set status='ended',ended_at=now() where id=p_meetup_id and status='active'; end if;
    perform maintain_meetup_lifecycle();
end;
$$;

revoke all on function public.meetup_has_access(uuid,uuid),public.maintain_meetup_lifecycle(),
    public.meetup_snapshot(uuid),public.meetup_command(text,uuid,jsonb),
    public.meetup_checkin_eligible(uuid),public.review_meetup_case(uuid,boolean,text,text) from public,anon,authenticated;
grant execute on function public.meetup_snapshot(uuid),public.meetup_command(text,uuid,jsonb),public.meetup_checkin_eligible(uuid) to authenticated;
grant execute on function public.maintain_meetup_lifecycle(),public.review_meetup_case(uuid,boolean,text,text) to service_role;
grant select,insert,update,delete on public.meetup_testers to service_role;
grant select on public.meetup_review_cases,public.meetup_reports to service_role;

-- Install the scheduler if pg_cron already exists. Otherwise provision the job as
-- a deployment step; the access deadline itself does not depend on the job.
do $$ begin
    if exists(select 1 from pg_extension where extname='pg_cron') then
        execute $job$select cron.schedule('snoots-meetup-lifecycle','* * * * *','select public.maintain_meetup_lifecycle()')$job$;
    end if;
end $$;
commit;
