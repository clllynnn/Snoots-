// Isolated PostgreSQL only. Never uses credentials or connects to the project.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.argv[2]));
const { pgcrypto } = await import(pathToFileURL(process.argv[2].replace(/index.js$/, 'contrib/pgcrypto.js')));
const db = new PGlite({ extensions: { pgcrypto } });
let count = 0, serial = 0;
const check = (condition, message) => { assert.ok(condition, message); count++; };
const eq = (actual, expected, message) => { assert.deepEqual(actual, expected, message); count++; };
const uid = i => `00000000-0000-0000-0000-${String(i).padStart(12,'0')}`;
const eid = i => `10000000-0000-0000-0000-${String(i).padStart(12,'0')}`;
const uuid = () => `20000000-0000-0000-0000-${String(++serial).padStart(12,'0')}`;
async function as(i) { await db.exec('reset role'); await db.query("select set_config('request.jwt.claim.sub',$1,false)",[uid(i)]); await db.exec('set role authenticated'); }
async function admin(sql, args = []) { await db.exec('reset role'); return db.query(sql, args); }
async function snap(event = null) { return (await db.query('select experience_snapshot($1) v',[event])).rows[0].v; }
async function cmd(action, event = null, payload = {}) { return (await db.query('select experience_command($1,$2,$3::jsonb) v',[action,event,JSON.stringify(payload)])).rows[0].v; }
async function denied(fn, text) { let error; try { await fn(); } catch(e) { error = e; } check(error && (!text || error.message.includes(text)),`Expected ${text ?? 'denial'}; received ${error?.message}`); }
async function prepareEvent(n, members = 5) {
    const event = eid(n);
    await admin(`insert into meetup_events(id,host_id,title,start_at,deadline,location,purpose,pace,capacity)
      values($1,$2,'測試散步',now()-interval '1 hour',now()-interval '2 hours','公園','低壓互動','平行散步',10)`,[event,uid(1)]);
    for(let i=1;i<=members;i++) {
        await db.query(`insert into meetup_applications(meetup_id,user_id,status,request_id) values($1,$2,'approved',$3)`,[event,uid(i),uuid()]);
        await db.query(`insert into meetup_confirmations values($1,$2,'rules',1,now())`,[event,uid(i)]);
    }
    return event;
}
try {
 await db.exec(`create extension pgcrypto; create role anon; create role authenticated; create role service_role bypassrls;
 create schema auth; create schema storage; create table auth.users(id uuid primary key);
 create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
 grant usage on schema auth,storage,public to anon,authenticated,service_role;
 create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text);
 create function storage.foldername(text) returns text[] language sql immutable as $$ select string_to_array($1,'/') $$;
 alter table storage.objects enable row level security;`);
 for (const file of ['20261013000000_account_profiles.sql','20261013010000_matching_profiles.sql','20261013020000_meetup_workflow.sql','20261013030000_onsite_feedback.sql','20261013040000_account_deletion_lifecycle.sql','20261013050000_meetup_start_boundary.sql']) {
    await db.exec(await readFile(new URL(`../../supabase/migrations/${file}`,import.meta.url),'utf8'));
 }
 for(let i=1;i<=8;i++) {
    await db.query('insert into auth.users values($1)',[uid(i)]);
    await db.query('insert into owner_profiles(user_id,nickname) values($1,$2)',[uid(i),`飼主${i}`]);
    await db.query(`insert into dog_profiles(user_id,name,breed,size,sex,is_neutered,social_style,photo_path) values($1,$2,'博美','small','male',false,'fearful_approach',$3)`,[uid(i),`狗狗${i}`,`${uid(i)}/dog.jpg`]);
    await db.query(`insert into storage.objects(bucket_id,name) values('dog-photos',$1)`,[`${uid(i)}/dog.jpg`]);
    if(i<8) await db.query('insert into meetup_testers values($1,false,true)',[uid(i)]);
 }
 const event = await prepareEvent(1);
 await as(8); await denied(()=>snap(),'資格');
 await as(2); await denied(()=>cmd('reception',event),'發起人');
 await denied(()=>cmd('start',event),'發起人');
 await as(1); await denied(()=>cmd('start',event),'三位');
 const ticket = await cmd('reception',event); check(ticket.token,'host obtains opaque token');
 await as(6); await denied(()=>cmd('checkin',event,{token:ticket.token}),'存取');
 await as(2); await denied(()=>cmd('checkin',event,{token:uuid()}),'憑證');
 await admin(`delete from meetup_confirmations where meetup_id=$1 and user_id=$2`,[event,uid(2)]);
 await as(2); await denied(()=>cmd('checkin',event,{token:ticket.token}),'安全守則');
 await admin(`insert into meetup_confirmations values($1,$2,'rules',1,now())`,[event,uid(2)]);
 await as(2); let s = await cmd('checkin',event,{token:ticket.token}); eq(s.onsite.checkedInCount,1,'automatic checkin saved');
 await cmd('checkin',event,{token:ticket.token}); eq((await snap(event)).onsite.checkedInCount,1,'idempotent checkin');
 await as(1); await cmd('manualCheckin',event,{targetID:uid(3)}); await cmd('manualCheckin',event,{targetID:uid(4)});
 s = await cmd('start',event); check(s.onsite.startedAt,'started after three other attendees');
 const startedAt = s.onsite.startedAt; eq((await cmd('start',event)).onsite.startedAt,startedAt,'start idempotent');
 await as(2); await cmd('away',event,{away:true}); eq((await snap(event)).onsite.members.find(m=>m.id===uid(2)).away,true,'away recorded');
 check((await db.query('select meetup_snapshot($1) v',[event])).rows[0].v.meetups[0].myStatus==='approved','away retains membership');
 await cmd('away',event,{away:false}); await denied(()=>cmd('end',event),'發起人');
 await as(1); s = await cmd('end',event); check(s.memoryAllowed,'host end immediately opens memories');
 const endedAt=s.onsite.endedAt; eq((await cmd('end',event)).onsite.endedAt,endedAt,'end timestamp immutable');
 await denied(()=>cmd('manualCheckin',event,{targetID:uid(5)}),'結束');
 await as(2); s = await snap(event); check(s.targets.every(t=>t.name===null),'recognition hides names');
 check(!s.targets.some(t=>t.id===uid(5)),'unattended member excluded');
 await denied(()=>cmd('recognize',event,{targetID:uid(3),answer:'wrong'}),'再想');
 await cmd('recognize',event,{targetID:uid(3),answer:'狗狗3'});
 s=await snap(event); check(s.targets.find(t=>t.id===uid(3)).recognized,'correct recognition unlocked');
 const answers={dogs:{state:'relaxed',labels:['禮貌相遇']},humans:{state:'support',labels:['需要保留距離']}};
 await denied(()=>cmd('observation',event,{targetID:uid(4),answers}),'辨識');
 await denied(()=>cmd('observation',event,{targetID:uid(3),answers:{dogs:{state:'support',labels:['禮貌相遇']}}}),'標籤');
 await cmd('observation',event,{targetID:uid(3),answers}); eq((await snap()).cards.length,0,'private observation creates no empty card');
 const cardID=uuid();
 await denied(()=>cmd('sendCard',event,{id:cardID,targetID:uid(3),answers,tags:['需要保留距離']}),'正向');
 await denied(()=>cmd('sendCard',event,{id:cardID,targetID:uid(3),answers,photoPath:`${uid(2)}/missing.jpg`}), '照片');
 await cmd('sendCard',event,{id:cardID,targetID:uid(3),answers,tags:['禮貌相遇'],body:'謝謝一起散步'});
 await cmd('sendCard',event,{id:cardID,targetID:uid(3),answers:{},body:'changed'});
 s=await snap(); eq(s.cards[0].body,'謝謝一起散步','lost-response retry cannot mutate sent card');
 await as(3); s=await snap(); eq(s.cards[0].viewedAt,null,'list fetch does not mark card read');
 eq(s.observations.length,1,'private observations visible only to dog owner');
 await denied(()=>cmd('invite',null,{id:cardID}),'查看');
 await cmd('readCard',null,{id:cardID}); await cmd('acknowledge',null,{id:cardID}); await cmd('invite',null,{id:cardID});
 const invitation=(await snap()).invites[0]; check(invitation,'explicit invite created');
 await as(2); await cmd('acceptInvite',null,{id:invitation.id});
 const friend=(await snap()).friends[0]; check(friend,'accept creates a conversation');
 const messageID=uuid(); await cmd('sendMessage',null,{id:messageID,friendshipID:friend.id,body:'你好'});
 await cmd('sendMessage',null,{id:messageID,friendshipID:friend.id,body:'你好'});
 eq((await snap()).friends[0].messages.length,1,'messages idempotent');
 await cmd('retractCard',null,{id:cardID}); s=await snap(); eq(s.friends.length,1,'retract retains friendship');
 await as(3); s=await snap(); eq(s.observations.length,0,'retract removes linked observation contribution');
 check(s.cards[0].withdrawalUnread,'viewed card gets withdrawal notice'); eq(s.cards[0].body,'','withdrawal contains no card text');
 eq(s.invites.length,1,'invitation independent from retraction');
 await cmd('readCard',null,{id:cardID}); eq((await snap()).cards[0].withdrawalUnread,false,'withdrawal notice read independently');
 await as(2); await cmd('recognize',event,{targetID:uid(4),answer:'狗狗4'});
 const unseen=uuid(); await cmd('sendCard',event,{id:unseen,targetID:uid(4),answers,tags:['禮貌相遇']});
 await cmd('retractCard',null,{id:unseen}); await as(4); eq((await snap()).cards.length,0,'unseen retraction leaves no trace');
 await as(2); await cmd('privateDetails',null,{vetName:'私人獸醫院',vetPhone:'123',socialPreference:'偏好獨處'});
 eq((await snap()).privateDetails.vetPhone,'123','own private contact persisted');
 await as(3); eq((await snap()).privateDetails.vetPhone,'','private contact not exposed to another user');
 await denied(()=>db.query('select * from dog_private_details'),'permission');
 // Only one observed event counts, regardless of multiple reviewers or later changes.
 await as(1); await cmd('recognize',event,{targetID:uid(3),answer:'狗狗3'}); await cmd('observation',event,{targetID:uid(3),answers});
 await as(4); await cmd('recognize',event,{targetID:uid(3),answer:'狗狗3'}); await cmd('observation',event,{targetID:uid(3),answers});
 await as(3); s=await snap(); eq(new Set(s.observations.filter(o=>o.answers.dogs.state!=='unobserved').map(o=>o.eventID)).size,1,'dedupe observation events');
 await as(1); await cmd('retractObservation',event,{targetID:uid(3)}); await as(3); eq((await snap()).observations.length,1,'retraction retains another observer');
 await as(2); await cmd('block',null,{targetID:uid(3)}); eq((await snap()).friends.length,0,'block removes relationship');
 await as(3); s=await snap(event); check(!s.targets.some(t=>t.id===uid(2)),'blocked dog hidden from wall');
 await denied(()=>cmd('sendMessage',null,{id:uuid(),friendshipID:friend.id,body:'blocked'}),'失效');
 await as(2); await cmd('unblock',null,{targetID:uid(3)}); eq((await snap()).friends.length,0,'unblock does not restore friendship');
 // Underfilled-at-start decision and date/expired token failures.
 const small=await prepareEvent(2,4); await as(1); await denied(()=>cmd('reception',small),'人數不足');
 await cmd('hostDecision',small); const smallTicket=await cmd('reception',small);
 const renewedTicket=await cmd('reception',small);
 await cmd('stopReception',small,{token:smallTicket.token});
 await as(2); await cmd('checkin',small,{token:renewedTicket.token});
 check((await snap(small)).onsite.checkedInCount===1,'stale stop cannot stop new reception');
 await as(1); await cmd('stopReception',small,{token:renewedTicket.token}); await as(2); await denied(()=>cmd('checkin',small,{token:renewedTicket.token}),'憑證');
 await as(1); await denied(()=>cmd('end',small),'尚未實際');
 await as(5); check(!(await snap(small)).memoryAllowed,'other event isolation');
 // Server-side expiration applies even to a stale, already-open feedback form.
 await admin('alter table meetup_events disable trigger capture_memory_audience');
 await admin("update meetup_events set ended_at=now()-interval '14 days' where id=$1",[event]);
 await admin('alter table meetup_events enable trigger capture_memory_audience');
 await as(4); s=await snap(event); check(!s.memoryAllowed,'14 day exact boundary denies memories');
 await denied(()=>cmd('observation',event,{targetID:uid(3),answers}),'到期');
 await denied(()=>cmd('recognize',event,{targetID:uid(3),answer:'狗狗3'}),'到期');
 // 24-hour card boundary, 30-day invite expiry and retained personal inbox after event expiry.
 const later=await prepareEvent(3);
 await as(1); for(let i=2;i<=4;i++) await cmd('manualCheckin',later,{targetID:uid(i)});
 await cmd('start',later); await cmd('end',later);
 await cmd('recognize',later,{targetID:uid(2),answer:'狗狗2'});
 const lateCard=uuid(); await cmd('sendCard',later,{id:lateCard,targetID:uid(2),answers,body:'保留的卡片'});
 await as(2); await cmd('readCard',null,{id:lateCard}); await cmd('invite',null,{id:lateCard});
 const expiring=(await snap()).invites.find(i=>i.recipientID===uid(1));
 await admin("update dog_friend_invites set created_at=now()-interval '30 days' where id=$1",[expiring.id]);
 await as(1); await denied(()=>cmd('acceptInvite',null,{id:expiring.id}),'自動收回');
 check(!(await snap()).invites.some(i=>i.id===expiring.id),'30-day invite removed from list');
 await admin("update warm_cards set sent_at=now()-interval '24 hours' where id=$1",[lateCard]);
 await as(1); await denied(()=>cmd('retractCard',null,{id:lateCard}),'24 小時');
 await admin('alter table meetup_events disable trigger capture_memory_audience');
 await admin("update meetup_events set ended_at=now()-interval '14 days' where id=$1",[later]);
 await admin('alter table meetup_events enable trigger capture_memory_audience');
 await as(2); check((await snap(later)).cards.some(c=>c.id===lateCard),'received card survives closed group');
 await admin("update warm_cards set sent_at=now()-interval '1 hour' where id=$1",[lateCard]);
 await as(1); await cmd('retractCard',null,{id:lateCard}); check((await snap()).cards.find(c=>c.id===lateCard).retractedAt,'late sender retains 24h retraction after group close');
 // Cancellation never unlocks memories, cannot be confused with direct ending.
 const empty=await prepareEvent(4,1); await as(1);
 await db.query('select meetup_command($1,$2,$3::jsonb)', ['requestEnd',empty,JSON.stringify({requestID:uuid(),reason:'天氣不適合'})]);
 const cancelled=(await db.query('select meetup_snapshot($1) v',[empty])).rows[0].v.meetups.find(e=>e.id===empty);
 eq(cancelled.status,'cancelled','never-approved event can cancel after confirmation');
 check(!(await snap(empty)).memoryAllowed,'cancelled event has no memories');
 await denied(()=>db.query('select meetup_command($1,$2,$3::jsonb)', ['send',empty,JSON.stringify({messageID:uuid(),text:'readonly'})]),'唯讀');
 const single=await prepareEvent(5,2); await as(1); const singleRequest=uuid();
 await db.query('select meetup_command($1,$2,$3::jsonb)', ['requestEnd',single,JSON.stringify({requestID:singleRequest,reason:'取消原因'})]);
 await admin("update meetup_end_requests set expires_at=now()-interval '1 second' where id=$1",[singleRequest]);
 await as(2); eq((await db.query('select meetup_snapshot($1) v',[single])).rows[0].v.meetups.find(e=>e.id===single).status,'cancelled','single-other-member request auto-approves at 24h deadline');
 // Account deletion is denied to clients; only a verified server transaction may begin it.
 await as(2); const profileUpdate={nickname:'測試暱稱',name:'狗狗2',breed:'新填犬種',size:'small',sex:'male',isNeutered:false,socialStyle:'fearful_approach',photoPath:`${uid(2)}/dog.jpg`};
 await db.query('select update_own_profile($1::jsonb)',[JSON.stringify(profileUpdate)]);
 await db.query('select update_own_profile($1::jsonb)',[JSON.stringify(profileUpdate)]);
 eq((await db.query('select breed_mapping_status from dog_profiles')).rows[0].breed_mapping_status,'pending','edited breed needs backend mapping');
 eq((await db.query('select * from pending_breed_mappings')).rows.length,1,'breed request deduplicated');
 await admin(`insert into storage.objects(bucket_id,name) values('warm-photos',$1)`,[`${uid(2)}/attached.jpg`]);
 await admin('update warm_cards set photo_path=$1 where id=$2',[`${uid(2)}/attached.jpg`,cardID]);
 await as(2); eq((await db.query('select can_delete_warm_photo($1) ok',[`${uid(2)}/attached.jpg`])).rows[0].ok,false,'sent attachment cannot be deleted independently');
 eq((await db.query('select can_delete_warm_photo($1) ok',[`${uid(2)}/draft.jpg`])).rows[0].ok,true,'unsubmitted upload can be discarded');
 await as(1); await denied(()=>db.query('select begin_account_deletion($1)',[uid(1)]),'permission');
 await admin('select begin_account_deletion($1)',[uid(1)]);
 await as(1); await denied(()=>snap(),'資格');
 eq((await db.query('select * from owner_profiles')).rows.length,0,'existing JWT can no longer read own profile during deletion');
 await admin('select 1'); await denied(()=>db.query('select finalize_account_deletion($1)',[uid(1)]),'Storage cleanup');
 await admin('delete from storage.objects where name like $1',[`${uid(1)}/%`]);
 await admin('select finalize_account_deletion($1)',[uid(1)]);
 await admin('delete from auth.users where id=$1',[uid(1)]);
 await as(1); eq((await db.query('select account_active() ok')).rows[0].ok,false,'deleted Auth user cannot regain Storage access with an unexpired JWT');
 eq((await admin('select * from owner_profiles where user_id=$1',[uid(1)])).rows.length,0,'Auth deletion cascades private profile');
 check((await admin('select * from meetup_events where id=$1',[small])).rows[0].host_id===null,'other participants event is retained without former host identity');
 await as(2); const retained=(await db.query('select meetup_snapshot($1) v',[small])).rows[0].v;
 check(retained.meetups.some(e=>e.id===small),'former-host deletion does not erase event from member list');
 console.log(`PASS: ${count} F19–F29 database assertions`);
} finally { await db.close(); }
