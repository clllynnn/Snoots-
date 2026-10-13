begin;
-- Keep other members' event/message history when the host deletes their account.
alter table public.meetup_events alter column host_id drop not null;
alter table public.meetup_events drop constraint meetup_events_host_id_fkey;
alter table public.meetup_events add constraint meetup_events_host_id_fkey foreign key(host_id) references auth.users on delete set null;
alter table public.meetup_events add column demo_audience boolean not null default false;
update public.meetup_events e set demo_audience=t.is_demo from public.meetup_testers t where t.user_id=e.host_id;
create function public.set_event_audience() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin select is_demo into new.demo_audience from meetup_testers where user_id=new.host_id; return new; end $$;
create trigger set_event_audience before insert on public.meetup_events for each row execute function public.set_event_audience();

create table public.account_deletion_evidence (
 id uuid primary key default gen_random_uuid(), meetup_id uuid not null references public.meetup_events on delete cascade,
 subject_id uuid not null, reason text not null, retained_at timestamptz not null default now()
);
alter table public.account_deletion_evidence enable row level security;
revoke all on public.account_deletion_evidence from public,anon,authenticated;
grant all on public.account_deletion_evidence to service_role;
create function public.account_active() returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and exists(select 1 from auth.users where id=auth.uid())
  and not exists(select 1 from account_deletion_requests where user_id=auth.uid());
$$;
do $$ declare t text;begin
 foreach t in array array['owner_profiles','dog_profiles','dog_matching_profiles','pending_breed_mappings'] loop
  execute format('create policy account_not_deleting on public.%I as restrictive for all to authenticated using(public.account_active()) with check(public.account_active())',t);
 end loop;
end $$;
create policy account_not_deleting on storage.objects as restrictive for all to authenticated using(public.account_active()) with check(public.account_active());

create function public.begin_account_deletion(p_user uuid) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 -- Call only after Apple revocation; service-role only. All remote access stops now.
 insert into account_deletion_requests(user_id,apple_revoked) values(p_user,true)
  on conflict(user_id) do update set apple_revoked=true;
 update meetup_testers set enabled=false where user_id=p_user;
 insert into account_deletion_evidence(meetup_id,subject_id,reason)
  select r.meetup_id,p_user,r.reason from meetup_reports r join meetup_review_cases c using(meetup_id)
  where c.status='pending' and r.user_id=p_user and not exists(select 1 from account_deletion_evidence ev where ev.meetup_id=r.meetup_id and ev.subject_id=p_user);
 update meetup_events set status=case when started_at is null then 'cancelled' else 'ended' end,ended_at=now()
  where host_id=p_user and status='active';
 delete from meetup_reception where meetup_id in(select id from meetup_events where host_id=p_user);
 update meetup_applications set status='left',shared_dog='{}',consent_fields='{}' where user_id=p_user;
 perform maintain_meetup_lifecycle();
end $$;
create function public.account_deletion_objects(p_user uuid) returns table(bucket text,path text) language sql security definer set search_path=public,storage,pg_temp as $$
 select bucket_id,name from storage.objects where split_part(name,'/',1)=p_user::text;
$$;
create function public.finalize_account_deletion(p_user uuid) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not exists(select 1 from account_deletion_requests where user_id=p_user and apple_revoked) then raise exception 'Deletion not authorized'; end if;
 if exists(select 1 from storage.objects where split_part(name,'/',1)=p_user::text) then raise exception 'Storage cleanup incomplete'; end if;
 delete from meetup_messages where sender_id=p_user;
 -- Auth deletion cascades owner/dog/matching, observations/cards, friendship messages,
 -- memberships, recognition, blocks, and invites. Never remove another author's posts.
 update account_deletion_requests set state='ready_for_auth_delete' where user_id=p_user;
end $$;
create function public.purge_closed_deletion_evidence() returns void language sql security definer set search_path=public,pg_temp as $$
 delete from account_deletion_evidence e where not exists(select 1 from meetup_review_cases c where c.meetup_id=e.meetup_id and c.status='pending');
$$;

-- A null/deleted host does not erase the other members' 14-day retained group.
create or replace function public.meetup_snapshot(p_selected uuid default null) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare u uuid:=experience_user(); result jsonb;begin
 perform maintain_meetup_lifecycle();
 select coalesce(jsonb_agg(jsonb_build_object(
 'id',e.id,'hostID',coalesce(e.host_id,'00000000-0000-0000-0000-000000000000'::uuid),'hostName',coalesce(o.nickname,'帳號已刪除'),
 'title',e.title,'startAt',extract(epoch from e.start_at),'deadline',extract(epoch from e.deadline),'location',e.location,'navigationURL',e.navigation_url,
 'purpose',e.purpose,'pace',e.pace,'capacity',e.capacity,'allowedSizes',to_jsonb(e.allowed_sizes),'venueRules',e.venue_rules,'extraEquipment',e.extra_equipment,
 'announcement',e.announcement,'status',e.status,'startedAt',extract(epoch from e.started_at),'endedAt',extract(epoch from e.ended_at),'inviteCode',e.invite_code,'version',e.version,
 'infoVersion',e.info_version,'equipmentVersion',e.equipment_version,'rulesVersion',e.rules_version,'myStatus',mine.status,'muted',coalesce(mine.muted,false),
 'unread',case when meetup_has_access(e.id,u) then (select count(*) from meetup_messages where meetup_id=e.id and created_at>mine.last_read_at and sender_id is distinct from u) else 0 end,
 'lastMessage',case when meetup_has_access(e.id,u) then (select body from meetup_messages where meetup_id=e.id order by created_at desc,id desc limit 1) end,
 'confirmations',coalesce((select jsonb_object_agg(section,version) from meetup_confirmations where meetup_id=e.id and user_id=u),'{}'),
 'members',coalesce((select jsonb_agg(jsonb_build_object('userID',a.user_id,'nickname',case when e.host_id=u and a.status='pending' then '' else op.nickname end,
  'status',a.status,'requestID',case when e.host_id=u then a.request_id end,
  'dog',case when e.host_id=u and meetup_has_access(e.id,u) then a.shared_dog else jsonb_build_object('name',d.name) end))
  from meetup_applications a join owner_profiles op on op.user_id=a.user_id join dog_profiles d on d.user_id=a.user_id
  where a.meetup_id=e.id and not dog_is_blocked(u,a.user_id) and (a.status='approved' or (e.host_id=u and meetup_has_access(e.id,u)))),'[]'),
 'messages',case when meetup_has_access(e.id,u) and e.id=p_selected then coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'senderID',m.sender_id,
  'senderName',m.sender_name,'text',m.body,'createdAt',extract(epoch from m.created_at)) order by m.created_at,m.id) from meetup_messages m where meetup_id=e.id),'[]') else '[]'::jsonb end,
 'endApplication',case when meetup_has_access(e.id,u) then (select jsonb_build_object('id',r.id,'expiresAt',extract(epoch from r.expires_at),'manualReview',r.manual_review,'reason',r.reason,'confirmedBy',
  coalesce((select jsonb_agg(v.user_id) from meetup_end_votes v join meetup_applications a on a.user_id=v.user_id and a.meetup_id=e.id where v.request_id=r.id and a.status='approved' and v.user_id<>e.host_id),'[]'))
  from meetup_end_requests r where r.meetup_id=e.id and r.closed_at is null and r.expires_at>now() limit 1) end
 ) order by e.start_at,e.id),'[]') into result
 from meetup_events e left join owner_profiles o on o.user_id=e.host_id
 join meetup_testers self_t on self_t.user_id=u and self_t.is_demo=e.demo_audience
 left join meetup_applications mine on mine.meetup_id=e.id and mine.user_id=u
 where e.status='active' or e.host_id=u or mine.user_id is not null;
 return jsonb_build_object('meetups',result,'selectedID',p_selected);
end $$;

revoke all on function public.account_active() from public,anon;
grant execute on function public.account_active() to authenticated;
revoke all on function public.set_event_audience(),public.begin_account_deletion(uuid),public.account_deletion_objects(uuid),public.finalize_account_deletion(uuid),public.purge_closed_deletion_evidence() from public,anon,authenticated;
grant execute on function public.begin_account_deletion(uuid),public.account_deletion_objects(uuid),public.finalize_account_deletion(uuid),public.purge_closed_deletion_evidence() to service_role;
commit;
