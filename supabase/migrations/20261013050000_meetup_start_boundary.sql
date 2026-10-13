-- Compatibility with F12–F18: cancellation remains distinct from on-site ending.
begin;
alter table public.meetup_events add column ever_had_participant boolean not null default false;
update public.meetup_events e set ever_had_participant=true where exists(select 1 from meetup_applications a where a.meetup_id=e.id and a.user_id<>e.host_id and a.status in('approved','left'));
alter table public.meetup_end_requests add column reason text not null default '';
alter table public.meetup_end_requests add column manual_review boolean not null default false;
alter table public.meetup_end_requests add column auto_approve boolean not null default false;
create function public.remember_approved_member() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.status='approved' then update meetup_events set ever_had_participant=true where id=new.meetup_id and host_id<>new.user_id; end if;
 return new;
end $$;
create trigger remember_approved_member after insert or update on public.meetup_applications for each row execute function public.remember_approved_member();

create or replace function public.meetup_has_access(p_id uuid,p_user uuid) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from meetup_events e join meetup_applications a on a.meetup_id=e.id join meetup_testers t on t.user_id=a.user_id
 where e.id=p_id and a.user_id=p_user and t.enabled and a.status='approved' and not exists(select 1 from account_deletion_requests where user_id=p_user)
 and (e.status='active' or (e.status in('ended','cancelled') and now()<e.ended_at+interval '14 days')));
$$;
create or replace function public.maintain_meetup_lifecycle() returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 -- A still-unreviewed single-participant cancellation is approved after exactly 24h,
 -- only while not started. Existing requests close atomically when start succeeds.
 update meetup_events e set status='cancelled',ended_at=now() from meetup_end_requests r
  where r.meetup_id=e.id and r.manual_review and r.auto_approve and r.closed_at is null and r.expires_at<=now() and e.status='active' and e.started_at is null;
 update meetup_end_requests r set closed_at=now() where closed_at is null and (expires_at<=now() or exists(select 1 from meetup_events e where e.id=r.meetup_id and (e.status<>'active' or e.started_at is not null)));
 update meetup_applications a set status='rejected' where a.status='pending' and exists(select 1 from meetup_events e where e.id=a.meetup_id and e.status in('cancelled','archived'));
 insert into meetup_messages(id,meetup_id,sender_name,body,system_key,created_at)
 select gen_random_uuid(),e.id,'系統',
  case when e.status='cancelled' then '這場狗聚已取消，群組僅供查看，不開啟共同回憶。' else '這場狗聚已結束。' end ||
  '群組保留至 '||to_char((e.ended_at+interval '14 days') at time zone 'Asia/Taipei','YYYY/MM/DD HH24:MI')||'（台灣時間）；個人聊天室不受影響。',
  'expiry-'||n.day_offset,e.ended_at+make_interval(days=>n.day_offset)
 from meetup_events e cross join(values(0),(11),(13)) n(day_offset)
 where e.status in('ended','cancelled','archived') and e.ended_at+make_interval(days=>n.day_offset)<=now()
 on conflict(meetup_id,system_key) do nothing;
 update meetup_events set status='archived',archived_at=now() where status in('ended','cancelled') and ended_at+interval '14 days'<=now();
 -- Preserve the scheduled event time, never reopen a started/cancelled event.
 update meetup_events e set deadline=e.start_at where e.status='active' and e.started_at is null and now()<e.start_at and e.deadline<=now()
  and (select count(*) from meetup_applications a where a.meetup_id=e.id and a.status='approved')<5;
 delete from account_deletion_evidence ev where not exists(select 1 from meetup_review_cases c where c.meetup_id=ev.meetup_id and c.status='pending');
end $$;

create or replace function public.meetup_command(p_action text,p_meetup_id uuid,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare u uuid:=experience_user();e meetup_events%rowtype;r meetup_end_requests%rowtype;n integer;begin
 perform maintain_meetup_lifecycle();
 select * into e from meetup_events where id=p_meetup_id for update;
 if p_action in ('requestEnd','approveEnd') then
  if e.started_at is not null then raise exception '已實際舉行，請至現場儀表板直接結束，不再審核。'; end if;
  if e.status<>'active' or not meetup_has_access(e.id,u) then raise exception '取消申請已失效。'; end if;
  select count(*) into n from meetup_applications where meetup_id=e.id and user_id<>e.host_id and status='approved';
  if p_action='requestEnd' then
   if e.host_id<>u then raise exception '只有發起人可申請取消。'; end if;
   if nullif(btrim(p_payload->>'reason'),'') is null or length(p_payload->>'reason')>1000 then raise exception '請填寫取消原因（1000 字內）。'; end if;
   if n=0 and not e.ever_had_participant then
    update meetup_events set status='cancelled',ended_at=now() where id=e.id;
    update meetup_applications set status='rejected' where meetup_id=e.id and status='pending';
   else
    -- Ever-approved with zero remaining cannot bypass safeguards by removing people.
    insert into meetup_end_requests(id,meetup_id,reason,manual_review,auto_approve,expires_at)
     values((p_payload->>'requestID')::uuid,e.id,p_payload->>'reason',n<2,n=1,now()+case when n=1 then interval '24 hours' else interval '48 hours' end)
     on conflict do nothing;
   end if;
  else
   if e.host_id=u then raise exception '發起人不能計入確認人數。'; end if;
   select * into r from meetup_end_requests where id=(p_payload->>'requestID')::uuid and meetup_id=e.id and closed_at is null and expires_at>now() for update;
   if not found or r.manual_review then raise exception '此申請等待後台審查，或已失效。'; end if;
   insert into meetup_end_votes values(r.id,u) on conflict do nothing;
   if (select count(*) from meetup_end_votes v join meetup_applications a on a.user_id=v.user_id and a.meetup_id=e.id where v.request_id=r.id and a.status='approved' and a.user_id<>e.host_id)>=2 then
    update meetup_events set status='cancelled',ended_at=now() where id=e.id;
    update meetup_end_requests set closed_at=now() where id=r.id;
    update meetup_applications set status='rejected' where meetup_id=e.id and status='pending';
   end if;
  end if;
  insert into meetup_messages(id,meetup_id,sender_name,body,system_key) values(gen_random_uuid(),e.id,'系統',
   case when p_action='requestEnd' then '發起人提出取消：'||(p_payload->>'reason') else '成員已確認取消申請，請查看活動狀態。' end,
   'cancel-'||(p_payload->>'requestID')||'-'||u::text) on conflict(meetup_id,system_key) do nothing;
  perform maintain_meetup_lifecycle(); return meetup_snapshot(e.id);
 end if;
 if e.status='cancelled' and p_action not in('read','mute','report') then raise exception '已取消的狗聚群組僅供唯讀查看。'; end if;
 return meetup_command_v1(p_action,p_meetup_id,p_payload);
end $$;
-- Explicit backend review; no client permissions. Do not reset a completed end time.
create or replace function public.review_meetup_case(p_meetup_id uuid,p_end boolean,p_reviewer text,p_note text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if nullif(btrim(p_reviewer),'') is null or nullif(btrim(p_note),'') is null then raise exception 'Reviewer and decision note required'; end if;
 perform 1 from meetup_events where id=p_meetup_id for update;
 update meetup_review_cases set status=case when p_end then 'ended' else 'dismissed' end,reviewed_at=now(),reviewer=p_reviewer,decision_note=p_note where meetup_id=p_meetup_id and status='pending';
 if not found then raise exception 'No pending review case'; end if;
 if p_end then update meetup_events set status=case when started_at is null then 'cancelled' else 'ended' end,ended_at=now() where id=p_meetup_id and status='active'; end if;
 perform maintain_meetup_lifecycle();
end $$;
revoke all on function public.remember_approved_member() from public,anon,authenticated;
create function public.review_meetup_cancellation(p_request uuid,p_approve boolean,p_reviewer text,p_note text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r meetup_end_requests%rowtype;e meetup_events%rowtype;begin
 if nullif(btrim(p_reviewer),'') is null or nullif(btrim(p_note),'') is null then raise exception 'Reviewer and note required'; end if;
 select * into r from meetup_end_requests where id=p_request;
 select * into e from meetup_events where id=r.meetup_id for update;
 if r.closed_at is not null or e.status<>'active' or e.started_at is not null then raise exception 'Cancellation no longer actionable'; end if;
 update meetup_end_requests set closed_at=now() where id=r.id;
 if p_approve then update meetup_events set status='cancelled',ended_at=now() where id=e.id;
  update meetup_applications set status='rejected' where meetup_id=e.id and status='pending'; end if;
 insert into meetup_messages(id,meetup_id,sender_name,body,system_key) values(gen_random_uuid(),e.id,'系統',case when p_approve then '取消申請已通過審查。' else '取消申請未通過審查。' end,'cancel-review-'||r.id);
 perform maintain_meetup_lifecycle();
end $$;
revoke all on function public.review_meetup_cancellation(uuid,boolean,text,text) from public,anon,authenticated;
grant execute on function public.review_meetup_cancellation(uuid,boolean,text,text) to service_role;
commit;
