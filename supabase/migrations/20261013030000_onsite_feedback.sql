-- F19–F29. Additive migration; never deploy with a client/service key in the app.
begin;
alter table public.meetup_events add column started_at timestamptz;
alter table public.meetup_events add column underfilled_confirmed_at timestamptz;
create table public.meetup_attendance (
 meetup_id uuid references public.meetup_events on delete cascade,
 user_id uuid references auth.users on delete cascade,
 checked_in_at timestamptz not null default now(),
 method text not null check(method in ('nearby','manual')),
 operator_id uuid references auth.users on delete set null,
 away boolean not null default false,
 primary key(meetup_id,user_id)
);
create table public.meetup_reception (
 meetup_id uuid primary key references public.meetup_events on delete cascade,
 token uuid not null unique default gen_random_uuid(),
 expires_at timestamptz not null default now()+interval '45 seconds'
);
-- Frozen end-of-event audience; late membership changes cannot manufacture attendance.
create table public.meetup_memory_members (
 meetup_id uuid references public.meetup_events on delete cascade,
 user_id uuid references auth.users on delete cascade,
 attended boolean not null,
 primary key(meetup_id,user_id)
);
create table public.dog_recognitions (
 meetup_id uuid references public.meetup_events on delete cascade,
 observer_id uuid references auth.users on delete cascade,
 target_id uuid references auth.users on delete cascade,
 primary key(meetup_id,observer_id,target_id), check(observer_id<>target_id)
);
create table public.dog_observations (
 meetup_id uuid references public.meetup_events on delete cascade,
 observer_id uuid references auth.users on delete cascade,
 target_id uuid references auth.users on delete cascade,
 answers jsonb not null default '{}',
 updated_at timestamptz not null default now(),
 retracted_at timestamptz,
 primary key(meetup_id,observer_id,target_id), check(observer_id<>target_id)
);
create table public.warm_cards (
 id uuid primary key,
 meetup_id uuid not null references public.meetup_events on delete cascade,
 sender_id uuid not null references auth.users on delete cascade,
 recipient_id uuid not null references auth.users on delete cascade,
 body text not null default '' check(length(body)<=1000),
 tags text[] not null default '{}', photo_path text,
 sent_at timestamptz not null default now(), viewed_at timestamptz, acknowledged_at timestamptz,
 retracted_at timestamptz, withdrawal_read_at timestamptz,
 unique(meetup_id,sender_id,recipient_id), check(sender_id<>recipient_id)
);
create table public.dog_friend_invites (
 id uuid primary key, sender_id uuid not null references auth.users on delete cascade,
 recipient_id uuid not null references auth.users on delete cascade,
 created_at timestamptz not null default now(), accepted_at timestamptz,
 check(sender_id<>recipient_id)
);
create unique index dog_pending_invite_pair on public.dog_friend_invites(least(sender_id,recipient_id),greatest(sender_id,recipient_id));
create table public.dog_friendships (
 id uuid primary key default gen_random_uuid(),
 first_id uuid not null references auth.users on delete cascade,
 second_id uuid not null references auth.users on delete cascade,
 created_at timestamptz not null default now(), unique(first_id,second_id),check(first_id<second_id)
);
create table public.dog_private_messages (
 id uuid primary key, friendship_id uuid not null references public.dog_friendships on delete cascade,
 sender_id uuid not null references auth.users on delete cascade,
 body text not null check(length(btrim(body)) between 1 and 2000), created_at timestamptz not null default now(), read_at timestamptz
);
create table public.dog_blocks (
 user_id uuid references auth.users on delete cascade, target_id uuid references auth.users on delete cascade,
 primary key(user_id,target_id),check(user_id<>target_id)
);
create table public.dog_private_details (
 user_id uuid primary key references auth.users on delete cascade,
 vet_name text not null default '' check(length(vet_name)<=100),
 vet_phone text not null default '' check(length(vet_phone)<=50),
 social_preference text not null default '' check(social_preference in ('','喜歡社交','能自在共處','選擇性社交','偏好獨處'))
);
create table public.account_deletion_requests (
 user_id uuid primary key references auth.users on delete cascade,
 requested_at timestamptz not null default now(), state text not null default 'processing',
 apple_revoked boolean not null default false
);
do $$ declare t text; begin
 foreach t in array array['meetup_attendance','meetup_reception','meetup_memory_members','dog_recognitions','dog_observations','warm_cards','dog_friend_invites','dog_friendships','dog_private_messages','dog_blocks','dog_private_details','account_deletion_requests'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from anon,authenticated',t);
  execute format('grant all on public.%I to service_role',t);
 end loop;
end $$;

create function public.dog_is_blocked(a uuid,b uuid) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from dog_blocks where (user_id=a and target_id=b) or (user_id=b and target_id=a));
$$;
create function public.experience_user() returns uuid language plpgsql stable security definer set search_path=public,pg_temp as $$
declare u uuid:=auth.uid(); begin
 if u is null or not exists(select 1 from meetup_testers where user_id=u and enabled)
 or exists(select 1 from account_deletion_requests where user_id=u) then raise exception '登入或測試資格已失效，請重新確認。'; end if;
 return u;
end $$;
create function public.memory_access(eid uuid,uid uuid) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from meetup_events e join meetup_memory_members m on m.meetup_id=e.id
 where e.id=eid and m.user_id=uid and e.status='ended' and e.started_at is not null and now()<e.ended_at+interval '14 days');
$$;
create function public.assert_checkin(eid uuid,uid uuid) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare e meetup_events%rowtype; begin
 select * into e from meetup_events where id=eid;
 if not found or e.status<>'active' then raise exception '這場狗聚已停止簽到。'; end if;
 if (now() at time zone 'Asia/Taipei')::date<>(e.start_at at time zone 'Asia/Taipei')::date then raise exception '請於活動當天簽到。'; end if;
 if not exists(select 1 from meetup_applications where meetup_id=eid and user_id=uid and status='approved')
 or not exists(select 1 from meetup_testers where user_id=uid and enabled)
 or exists(select 1 from account_deletion_requests where user_id=uid) then raise exception '尚未取得有效參加資格。'; end if;
 if not exists(select 1 from meetup_confirmations where meetup_id=eid and user_id=uid and section='rules' and version=e.rules_version) then raise exception '請先確認目前版本的安全守則。'; end if;
 if now()>=e.start_at and e.started_at is null and e.underfilled_confirmed_at is null
 and (select count(*) from meetup_applications where meetup_id=eid and status='approved')<5 then raise exception '人數不足，等待發起人確認照常舉辦。'; end if;
end $$;
create function public.capture_memory_audience() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if old.ended_at is not null and new.ended_at is distinct from old.ended_at then raise exception '結束時間不能重設。'; end if;
 if old.status='active' and new.status='ended' and new.started_at is not null then
  insert into meetup_memory_members select new.id,a.user_id,exists(select 1 from meetup_attendance c where c.meetup_id=new.id and c.user_id=a.user_id)
   from meetup_applications a where a.meetup_id=new.id and a.status='approved' on conflict do nothing;
 end if;
 return new;
end $$;
create trigger capture_memory_audience before update on public.meetup_events for each row execute function public.capture_memory_audience();

-- This table is the single source of allowed labels; private/help labels never leave on a warm card.
create function public.observation_labels(d text,s text) returns text[] language sql immutable as $$
 select case d||':'||s
 when 'humans:relaxed' then array['願意打招呼','與陌生人相處自在'] when 'humans:support' then array['先觀察陌生人','需要保留距離']
 when 'dogs:relaxed' then array['禮貌相遇','平行散步自在'] when 'dogs:support' then array['保持安全距離','需要慢慢熟悉']
 when 'environment:relaxed' then array['自在探索環境','遇干擾後恢復步調'] when 'environment:support' then array['需要安靜路線','需要更多適應時間']
 when 'handling:relaxed' then array['接受飼主輕觸','配戴裝備順利'] when 'handling:support' then array['觸碰時需要時間','操作時需要暫停']
 when 'focus:relaxed' then array['玩耍節奏舒適','能回應飼主引導'] when 'focus:support' then array['需要放慢節奏','需要暫停互動']
 else array[]::text[] end;
$$;
create function public.validate_observations(answers jsonb) returns void language plpgsql immutable as $$
declare d text;s text;ls text[];begin
 if jsonb_typeof(answers)<>'object' then raise exception '觀察格式不正確。'; end if;
 for d in select jsonb_object_keys(answers) loop
  if d<>all(array['humans','dogs','environment','handling','focus']) then raise exception '未知觀察面向。'; end if;
  s:=answers->d->>'state'; ls:=array(select jsonb_array_elements_text(coalesce(answers->d->'labels','[]')));
  if s is null or s<>all(array['relaxed','support','unobserved']) or cardinality(ls)>2
    or not ls<@public.observation_labels(d,s) then raise exception '請選擇符合觀察狀態的標籤（最多兩項）。'; end if;
 end loop;
end $$;

create function public.experience_snapshot(p_event uuid default null) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare u uuid:=experience_user(); result jsonb; e meetup_events%rowtype; onsite jsonb:=null; targets jsonb:='[]';choices jsonb:='[]'; begin
 perform maintain_meetup_lifecycle();
 select * into e from meetup_events where id=p_event;
 if found and meetup_has_access(e.id,u) then
  onsite:=jsonb_build_object('eventID',e.id,'startedAt',extract(epoch from e.started_at),'endedAt',extract(epoch from e.ended_at),
   'underfilledConfirmed',e.underfilled_confirmed_at is not null,'hostID',coalesce(e.host_id,'00000000-0000-0000-0000-000000000000'::uuid),'status',e.status,
   'approvedCount',(select count(*) from meetup_applications where meetup_id=e.id and status='approved'),
   'checkedInCount',(select count(*) from meetup_attendance c join meetup_applications a using(meetup_id,user_id) where c.meetup_id=e.id and a.status='approved' and c.user_id<>e.host_id),
   'members',coalesce((select jsonb_agg(jsonb_build_object('id',a.user_id,'name',d.name,'breed',d.breed,'photoPath',d.photo_path,
    'checkedInAt',extract(epoch from c.checked_in_at),'method',c.method,'away',coalesce(c.away,false),'reaction',a.shared_dog->>'reaction') order by d.name)
    from meetup_applications a join dog_profiles d on d.user_id=a.user_id left join meetup_attendance c on c.meetup_id=a.meetup_id and c.user_id=a.user_id
    where a.meetup_id=e.id and a.status='approved' and not dog_is_blocked(u,a.user_id)),'[]'));
 end if;
 if memory_access(p_event,u) then
  select coalesce(jsonb_agg(jsonb_build_object('id',m.user_id,'name',case when r.target_id is not null then d.name end,'breed',d.breed,'photoPath',d.photo_path,
   'recognized',r.target_id is not null,'answers',case when o.retracted_at is null then coalesce(o.answers,'{}') else '{}'::jsonb end,
   'cardSent',exists(select 1 from warm_cards w where w.meetup_id=m.meetup_id and w.sender_id=u and w.recipient_id=m.user_id)) order by d.id),'[]') into targets
   from meetup_memory_members m join dog_profiles d on d.user_id=m.user_id
   left join dog_recognitions r on r.meetup_id=m.meetup_id and r.target_id=m.user_id and r.observer_id=u
   left join dog_observations o on o.meetup_id=m.meetup_id and o.target_id=m.user_id and o.observer_id=u
   where m.meetup_id=p_event and m.attended and m.user_id<>u and not dog_is_blocked(u,m.user_id);
  select coalesce(jsonb_agg(distinct d.name),'[]') into choices from meetup_memory_members m join dog_profiles d on d.user_id=m.user_id
   where m.meetup_id=p_event and m.attended and m.user_id<>u and not dog_is_blocked(u,m.user_id);
 end if;
 select jsonb_build_object('serverTime',extract(epoch from now()),'onsite',onsite,'memoryAllowed',memory_access(p_event,u),'targets',targets,'nameChoices',choices,
  'cards',coalesce((select jsonb_agg(jsonb_build_object('id',w.id,'eventID',w.meetup_id,'senderID',w.sender_id,'recipientID',w.recipient_id,
   'senderName',sd.name,'recipientName',rd.name,'body',case when w.retracted_at is null then w.body else '' end,
   'tags',case when w.retracted_at is null then to_jsonb(w.tags) else '[]'::jsonb end,'photoPath',case when w.retracted_at is null then w.photo_path end,
   'sentAt',extract(epoch from w.sent_at),'viewedAt',extract(epoch from w.viewed_at),'acknowledged',w.acknowledged_at is not null,
   'retractedAt',extract(epoch from w.retracted_at),'withdrawalUnread',w.retracted_at is not null and w.viewed_at is not null and w.withdrawal_read_at is null)
   order by w.sent_at desc) from warm_cards w join dog_profiles sd on sd.user_id=w.sender_id join dog_profiles rd on rd.user_id=w.recipient_id
   where (w.sender_id=u or (w.recipient_id=u and (w.retracted_at is null or w.viewed_at is not null))) and not dog_is_blocked(w.sender_id,w.recipient_id)),'[]'),
  'invites',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'senderID',i.sender_id,'recipientID',i.recipient_id,'senderName',sd.name,'recipientName',rd.name,
   'createdAt',extract(epoch from i.created_at),'accepted',i.accepted_at is not null) order by i.created_at desc)
   from dog_friend_invites i join dog_profiles sd on sd.user_id=i.sender_id join dog_profiles rd on rd.user_id=i.recipient_id
   where (i.sender_id=u or i.recipient_id=u) and not dog_is_blocked(i.sender_id,i.recipient_id) and (i.accepted_at is not null or now()<i.created_at+interval '30 days')),'[]'),
  'friends',coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'userID',d.user_id,'name',d.name,'nickname',o.nickname,'photoPath',d.photo_path,
   'unread',(select count(*) from dog_private_messages m where m.friendship_id=f.id and m.sender_id<>u and m.read_at is null),
   'messages',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'senderID',m.sender_id,'text',m.body,'createdAt',extract(epoch from m.created_at)) order by m.created_at,m.id)
    from dog_private_messages m where m.friendship_id=f.id),'[]'))) from dog_friendships f
   join dog_profiles d on d.user_id=case when f.first_id=u then f.second_id else f.first_id end join owner_profiles o on o.user_id=d.user_id
   where u in (f.first_id,f.second_id) and not dog_is_blocked(f.first_id,f.second_id)),'[]'),
  'observations',coalesce((select jsonb_agg(jsonb_build_object('eventID',o.meetup_id,'eventName',observed_event.title,'sourceName',d.name,'answers',o.answers,'updatedAt',extract(epoch from o.updated_at)) order by o.updated_at desc)
   from dog_observations o join meetup_events observed_event on observed_event.id=o.meetup_id join dog_profiles d on d.user_id=o.observer_id where o.target_id=u and o.retracted_at is null),'[]'),
  'blocks',coalesce((select jsonb_agg(jsonb_build_object('id',b.target_id,'name',d.name)) from dog_blocks b join dog_profiles d on d.user_id=b.target_id where b.user_id=u),'[]'),
  'privateDetails',coalesce((select jsonb_build_object('vetName',vet_name,'vetPhone',vet_phone,'socialPreference',social_preference) from dog_private_details where user_id=u),'{"vetName":"","vetPhone":"","socialPreference":""}'::jsonb)
 ) into result; return result;
end $$;

create function public.experience_command(p_action text,p_event uuid default null,p_payload jsonb default '{}') returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare u uuid:=experience_user();e meetup_events%rowtype; target uuid; card warm_cards%rowtype; invitation dog_friend_invites%rowtype;
 token uuid; answers jsonb; tags text[]; path text; fid uuid;begin
 -- All event-dependent operations take the same row lock as existing meetup RPCs.
 if p_event is not null then select * into e from meetup_events where id=p_event for update;
  if not found then raise exception '找不到狗聚。'; end if;
 end if;
 target:=nullif(p_payload->>'targetID','')::uuid;
 if p_action in ('hostDecision','reception','stopReception','checkin','manualCheckin','start','end','away') then
  if not meetup_has_access(p_event,u) then raise exception '沒有這場活動的存取權。'; end if;
  if p_action='end' and e.status='ended' then return experience_snapshot(p_event); end if;
  if e.status<>'active' then raise exception '活動已結束，不能再操作。'; end if;
  if p_action in ('hostDecision','reception','stopReception','manualCheckin','start','end') and e.host_id<>u then raise exception '只有本場發起人可執行。'; end if;
  case p_action
  when 'hostDecision' then
   if now()<e.start_at or e.started_at is not null then raise exception '目前不需要低人數舉辦決定。'; end if;
   update meetup_events set underfilled_confirmed_at=coalesce(underfilled_confirmed_at,now()) where id=p_event;
  when 'reception' then
   perform assert_checkin(p_event,u);
   insert into meetup_reception(meetup_id) values(p_event) on conflict(meetup_id) do update set token=gen_random_uuid(),expires_at=now()+interval '45 seconds' returning meetup_reception.token into token;
   return jsonb_build_object('token',token,'eventID',p_event);
  when 'stopReception' then delete from meetup_reception where meetup_id=p_event and meetup_reception.token=(p_payload->>'token')::uuid;
  when 'manualCheckin' then
   if target is null then raise exception '請選擇要簽到的成員。'; end if;
   perform assert_checkin(p_event,target);
   insert into meetup_attendance(meetup_id,user_id,method,operator_id) values(p_event,target,'manual',u) on conflict do nothing;
  when 'checkin' then
   perform assert_checkin(p_event,u);
   if not exists(select 1 from meetup_reception where meetup_id=p_event and meetup_reception.token=(p_payload->>'token')::uuid and expires_at>now()) then raise exception '接待已停止或憑證過期，請重新尋找發起人。'; end if;
   insert into meetup_attendance(meetup_id,user_id,method,operator_id) values(p_event,u,'nearby',e.host_id) on conflict do nothing;
  when 'start' then
   if e.started_at is not null then return experience_snapshot(p_event); end if;
   perform assert_checkin(p_event,u);
   if (select count(*) from meetup_attendance c join meetup_applications a using(meetup_id,user_id) where c.meetup_id=p_event and c.user_id<>u and a.status='approved')<3 then raise exception '需至少三位其他核准成員完成現場簽到。'; end if;
   insert into meetup_attendance(meetup_id,user_id,method,operator_id) values(p_event,u,'manual',u) on conflict do nothing;
   update meetup_events set started_at=now(),version=version+1 where id=p_event;
   update meetup_end_requests set closed_at=now() where meetup_id=p_event and closed_at is null;
  when 'end' then
   if e.started_at is null then raise exception '尚未實際舉行，請使用取消活動流程。'; end if;
   update meetup_events set status='ended',ended_at=now(),version=version+1 where id=p_event;
   delete from meetup_reception where meetup_id=p_event;
  when 'away' then
   if e.started_at is null then raise exception '狗聚尚未開始。'; end if;
   update meetup_attendance set away=coalesce((p_payload->>'away')::boolean,false) where meetup_id=p_event and user_id=u;
   if not found then raise exception '請先完成簽到。'; end if;
  end case;
 elsif p_action in ('recognize','observation','sendCard') then
  if not memory_access(p_event,u) or target is null or target=u or dog_is_blocked(u,target)
   or not exists(select 1 from meetup_memory_members where meetup_id=p_event and user_id=target and attended)
   or not exists(select 1 from meetup_memory_members where meetup_id=p_event and user_id=u and attended) then raise exception '共同回憶已到期，或不符合本場實際參與資格。'; end if;
  if p_action='recognize' then
   if not exists(select 1 from dog_profiles where user_id=target and name=p_payload->>'answer') then raise exception '再想一下，可以參考品種與照片，或先跳過。'; end if;
   insert into dog_recognitions values(p_event,u,target) on conflict do nothing;
  else
   if not exists(select 1 from dog_recognitions where meetup_id=p_event and observer_id=u and target_id=target) then raise exception '請先完成狗狗辨識。'; end if;
   answers:=coalesce(p_payload->'answers','{}'); perform validate_observations(answers);
   if exists(select 1 from warm_cards where meetup_id=p_event and sender_id=u and recipient_id=target and retracted_at is not null) then raise exception '這次卡片與觀察已撤回，不能重新提交。'; end if;
   if p_action='sendCard' then
    -- Return existing record before mutating answers: lost-response retries cannot overwrite immutable content.
    if exists(select 1 from warm_cards where meetup_id=p_event and sender_id=u and recipient_id=target) then return experience_snapshot(p_event); end if;
    tags:=array(select jsonb_array_elements_text(coalesce(p_payload->'tags','[]')));
    if not tags<@array(select jsonb_array_elements_text(v.value->'labels') from jsonb_each(answers) v where v.value->>'state'='relaxed') then raise exception '暖心卡只能包含本次已觀察的正向標籤。'; end if;
    path:=nullif(p_payload->>'photoPath','');
    if path is not null and (split_part(path,'/',1)<>u::text or not exists(select 1 from storage.objects where bucket_id='warm-photos' and name=path)) then raise exception '照片尚未上傳完成。'; end if;
    if length(btrim(coalesce(p_payload->>'body','')))=0 and cardinality(tags)=0 and path is null then raise exception '只有私人觀察時請選擇儲存觀察。'; end if;
    insert into warm_cards(id,meetup_id,sender_id,recipient_id,body,tags,photo_path) values((p_payload->>'id')::uuid,p_event,u,target,coalesce(p_payload->>'body',''),tags,path);
   end if;
   insert into dog_observations(meetup_id,observer_id,target_id,answers) values(p_event,u,target,answers)
    on conflict(meetup_id,observer_id,target_id) do update set answers=excluded.answers,updated_at=now(),retracted_at=null;
  end if;
 elsif p_action='retractObservation' then
  if not memory_access(p_event,u) then raise exception '共同回憶已到期。'; end if;
  update dog_observations set retracted_at=coalesce(retracted_at,now()) where meetup_id=p_event and observer_id=u and target_id=target;
 elsif p_action in ('readCard','acknowledge','retractCard','invite') then
  select * into card from warm_cards where id=(p_payload->>'id')::uuid for update;
  if not found or u not in(card.sender_id,card.recipient_id) or dog_is_blocked(card.sender_id,card.recipient_id) then raise exception '無法存取這張卡片。'; end if;
  if p_action='retractCard' then
   if u<>card.sender_id then raise exception '只有寄件者可撤回。'; end if;
   if card.retracted_at is not null then return experience_snapshot(p_event); end if;
   if now()>=card.sent_at+interval '24 hours' then raise exception '已超過送出後 24 小時的撤回期限。'; end if;
   update warm_cards set retracted_at=now() where id=card.id;
   update dog_observations set retracted_at=now() where meetup_id=card.meetup_id and observer_id=u and target_id=card.recipient_id;
  else
   if u<>card.recipient_id then raise exception '只有收件者可執行。'; end if;
   if card.retracted_at is not null then
    if p_action='readCard' and card.viewed_at is not null then update warm_cards set withdrawal_read_at=now() where id=card.id;
    else raise exception '卡片已撤回。'; end if;
   elsif p_action='readCard' then update warm_cards set viewed_at=coalesce(viewed_at,now()) where id=card.id;
   elsif card.viewed_at is null then raise exception '請先查看卡片。';
   elsif p_action='acknowledge' then update warm_cards set acknowledged_at=coalesce(acknowledged_at,now()) where id=card.id;
   else
    -- Friend invitations are independent of cards and observations after creation.
    if not exists(select 1 from dog_friendships where first_id=least(u,card.sender_id) and second_id=greatest(u,card.sender_id)) then
     insert into dog_friend_invites(id,sender_id,recipient_id) values(gen_random_uuid(),u,card.sender_id) on conflict do nothing;
    end if;
   end if;
  end if;
 elsif p_action='acceptInvite' then
  select * into invitation from dog_friend_invites where id=(p_payload->>'id')::uuid for update;
  if not found or invitation.recipient_id<>u or dog_is_blocked(u,invitation.sender_id) then raise exception '無法接受此邀請。'; end if;
  if invitation.accepted_at is null and now()>=invitation.created_at+interval '30 days' then raise exception '好友邀請已自動收回。'; end if;
  update dog_friend_invites set accepted_at=coalesce(accepted_at,now()) where id=invitation.id;
  insert into dog_friendships(first_id,second_id) values(least(u,invitation.sender_id),greatest(u,invitation.sender_id)) on conflict do nothing;
 elsif p_action in ('sendMessage','readChat','block','unblock') then
  if p_action in ('block','unblock') then
   if target is null or target=u then raise exception '無效對象。'; end if;
   if p_action='unblock' then delete from dog_blocks where user_id=u and target_id=target;
   else
    if not exists(select 1 from dog_friendships where first_id=least(u,target) and second_id=greatest(u,target)) then raise exception '無法操作此對象。'; end if;
    insert into dog_blocks values(u,target) on conflict do nothing;
    delete from dog_friendships where first_id=least(u,target) and second_id=greatest(u,target);
    delete from dog_friend_invites where least(sender_id,recipient_id)=least(u,target) and greatest(sender_id,recipient_id)=greatest(u,target);
   end if;
  else
   fid:=(p_payload->>'friendshipID')::uuid;
   if not exists(select 1 from dog_friendships where id=fid and u in(first_id,second_id) and not dog_is_blocked(first_id,second_id)) then raise exception '聊天室已失效。'; end if;
   if p_action='readChat' then update dog_private_messages set read_at=coalesce(read_at,now()) where friendship_id=fid and sender_id<>u;
   else insert into dog_private_messages(id,friendship_id,sender_id,body) values((p_payload->>'id')::uuid,fid,u,p_payload->>'body') on conflict(id) do nothing; end if;
  end if;
 elsif p_action='privateDetails' then
  insert into dog_private_details(user_id,vet_name,vet_phone,social_preference) values(u,coalesce(p_payload->>'vetName',''),coalesce(p_payload->>'vetPhone',''),coalesce(p_payload->>'socialPreference',''))
   on conflict(user_id) do update set vet_name=excluded.vet_name,vet_phone=excluded.vet_phone,social_preference=excluded.social_preference;
 else raise exception '不支援的操作。'; end if;
 return experience_snapshot(p_event);
end $$;

-- Prevent obsolete end-request screens/RPC clients bypassing the new start boundary.
alter function public.meetup_command(text,uuid,jsonb) rename to meetup_command_v1;
create function public.meetup_command(p_action text,p_meetup_id uuid,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare e meetup_events%rowtype;begin
 perform experience_user();
 select * into e from meetup_events where id=p_meetup_id for update;
 if p_action in ('requestEnd','approveEnd') then
  raise exception '舊結束申請已停用；已開始的狗聚請從現場儀表板直接結束。尚未舉行請使用取消活動流程。';
 end if;
 return meetup_command_v1(p_action,p_meetup_id,p_payload);
end $$;

-- Profile updates are one transaction; submitted matching answers remain separately versioned.
create function public.update_own_profile(p_data jsonb) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare u uuid:=experience_user(); path text:=p_data->>'photoPath'; changed_breed boolean;begin
 if split_part(path,'/',1)<>u::text or not exists(select 1 from storage.objects where bucket_id='dog-photos' and name=path) then raise exception '照片尚未儲存。'; end if;
 select breed is distinct from btrim(p_data->>'breed') into changed_breed from dog_profiles where user_id=u for update;
 update owner_profiles set nickname=p_data->>'nickname' where user_id=u;
 update dog_profiles set name=p_data->>'name',breed=btrim(p_data->>'breed'),size=p_data->>'size',sex=p_data->>'sex',
  breed_mapping_status=case when changed_breed then 'pending' else breed_mapping_status end,
  is_neutered=(p_data->>'isNeutered')::boolean,social_style=p_data->>'socialStyle',photo_path=path where user_id=u;
 if changed_breed then
  insert into pending_breed_mappings(user_id,original_label) select u,btrim(p_data->>'breed')
   where not exists(select 1 from pending_breed_mappings where user_id=u and original_label=btrim(p_data->>'breed') and status='pending');
 end if;
end $$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('warm-photos','warm-photos',false,10485760,array['image/jpeg']) on conflict(id) do nothing;
create function public.can_read_experience_photo(bucket text,path text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select not exists(select 1 from account_deletion_requests where user_id=auth.uid()) and (
 (bucket='warm-photos' and exists(select 1 from warm_cards c where c.photo_path=path and c.retracted_at is null and auth.uid() in(c.sender_id,c.recipient_id) and not dog_is_blocked(c.sender_id,c.recipient_id)))
 or (bucket='dog-photos' and exists(select 1 from dog_profiles d where d.photo_path=path and not dog_is_blocked(auth.uid(),d.user_id) and (
 exists(select 1 from meetup_applications a join meetup_applications b using(meetup_id) where a.user_id=auth.uid() and b.user_id=d.user_id and b.status='approved' and meetup_has_access(a.meetup_id,auth.uid()))
 or exists(select 1 from meetup_memory_members m where m.user_id=d.user_id and m.attended and memory_access(m.meetup_id,auth.uid()))
 or exists(select 1 from dog_friendships where auth.uid() in(first_id,second_id) and d.user_id in(first_id,second_id))))));
$$;
create policy experience_photos_read on storage.objects for select to authenticated using(public.can_read_experience_photo(bucket_id,name));
create policy warm_photo_insert on storage.objects for insert to authenticated with check(bucket_id='warm-photos' and (storage.foldername(name))[1]=auth.uid()::text and not exists(select 1 from public.account_deletion_requests where user_id=auth.uid()));
-- Use a security-definer helper rather than giving clients deletion-request table access.
drop policy warm_photo_insert on storage.objects;
create policy warm_photo_insert on storage.objects for insert to authenticated with check(bucket_id='warm-photos' and (storage.foldername(name))[1]=auth.uid()::text);
create policy warm_photo_own_read on storage.objects for select to authenticated using(bucket_id='warm-photos' and (storage.foldername(name))[1]=auth.uid()::text);
-- An attachment is immutable once sent; only unsubmitted uploads can be discarded.
create function public.can_delete_warm_photo(path text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select split_part(path,'/',1)=auth.uid()::text and not exists(select 1 from warm_cards where photo_path=path);
$$;
revoke all on function public.can_delete_warm_photo(text) from public,anon;
grant execute on function public.can_delete_warm_photo(text) to authenticated;
create policy warm_photo_own_delete on storage.objects for delete to authenticated using(bucket_id='warm-photos' and public.can_delete_warm_photo(name));

-- No definer helper may be called directly to inspect somebody else's private data.
revoke all on function public.meetup_command_v1(text,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.dog_is_blocked(uuid,uuid),public.experience_user(),public.memory_access(uuid,uuid),public.assert_checkin(uuid,uuid),public.capture_memory_audience(),public.validate_observations(jsonb) from public,anon,authenticated;
revoke all on function public.experience_snapshot(uuid),public.experience_command(text,uuid,jsonb),public.update_own_profile(jsonb),public.meetup_command(text,uuid,jsonb) from public,anon;
grant execute on function public.experience_snapshot(uuid),public.experience_command(text,uuid,jsonb),public.update_own_profile(jsonb),public.meetup_command(text,uuid,jsonb) to authenticated;
revoke all on function public.can_read_experience_photo(text,text) from public,anon;
grant execute on function public.can_read_experience_photo(text,text) to authenticated;
commit;
