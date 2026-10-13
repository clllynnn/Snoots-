// Run: node app/Tests/MeetupDatabaseTests.mjs /absolute/path/to/pglite/package/dist/index.js
// Uses an isolated in-memory Postgres. Never connects to the deployed Supabase project.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.argv[2]));
const { pgcrypto } = await import(pathToFileURL(process.argv[2].replace(/index.js$/, 'contrib/pgcrypto.js')));
const db = new PGlite({ extensions: { pgcrypto } });
let tests = 0;
const ok = (value, message) => { assert.ok(value, message); tests++; };
const equal = (value, expected, message) => { assert.deepEqual(value, expected, message); tests++; };
const users = Array.from({ length: 9 }, (_, i) => `00000000-0000-0000-0000-${String(i + 1).padStart(12, '0')}`);
const event = '10000000-0000-0000-0000-000000000001';
const otherEvent = '10000000-0000-0000-0000-000000000002';
let serial = 0;
const uuid = () => `20000000-0000-0000-0000-${String(++serial).padStart(12, '0')}`;
async function as(user, role = 'authenticated') {
    await db.exec('reset role');
    await db.query(`select set_config('request.jwt.claim.sub', $1, false)`, [user]);
    await db.exec(`set role ${role}`);
}
async function command(action, id = event, payload = {}) {
    const r = await db.query('select public.meetup_command($1,$2,$3::jsonb) result', [action, id, JSON.stringify(payload)]);
    return r.rows[0].result;
}
async function snapshot(id = event) {
    return (await db.query('select public.meetup_snapshot($1) result', [id])).rows[0].result;
}
async function denied(fn, contains) {
    let error;
    try { await fn(); } catch (e) { error = e; }
    ok(error && (!contains || error.message.includes(contains)), `Expected rejection: ${contains ?? ''}; got ${error?.message}`);
}

try {
    await db.exec(`
        create extension pgcrypto;
        create role anon; create role authenticated; create role service_role bypassrls;
        create schema auth; create schema storage;
        create table auth.users(id uuid primary key);
        create function auth.uid() returns uuid language sql stable as $$
            select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
        grant usage on schema auth,storage,public to anon,authenticated,service_role;
        create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
        create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text);
        create function storage.foldername(text) returns text[] language sql immutable as $$ select string_to_array($1,'/') $$;
        alter table storage.objects enable row level security;
    `);
    for (const file of ['20261013000000_account_profiles.sql','20261013010000_matching_profiles.sql','20261013020000_meetup_workflow.sql']) {
        await db.exec(await readFile(new URL(`../../supabase/migrations/${file}`, import.meta.url), 'utf8'));
    }
    for (const [i, user] of users.entries()) {
        await db.query('insert into auth.users values($1)', [user]);
        await db.query('insert into owner_profiles(user_id,nickname) values($1,$2)', [user, `飼主${i}`]);
        await db.query(`insert into dog_profiles(user_id,name,breed,size,sex,is_neutered,social_style,photo_path)
            values($1,$2,'博美',$3,'male',false,'bark_or_growl',$4)`, [user, `狗狗${i}`, i === 7 ? 'large' : 'small', `${user}/photo.jpg`]);
        await db.query(`insert into dog_matching_profiles(user_id,birth_date,activity_needs,activity_preferences,first_meeting_pace)
            values($1,'2024-01-01',array['無特殊需求'],array['散步'],'先保持距離平行散步')`, [user]);
        if (i < 8) await db.query('insert into meetup_testers(user_id,is_demo) values($1,$2)', [user, i === 6]);
    }
    await as(users[8]);
    await denied(() => snapshot(), '測試名單');
    await as(users[0]);
    const form = { title: '公園散步', startAt: Date.now()/1000 + 86400*7, deadline: Date.now()/1000 + 86400*6,
        location: '大安森林公園', navigationURL: '', purpose: '慢慢認識', pace: '先保持距離平行散步',
        capacity: 6, allowedSizes: ['small'], venueRules: '', extraEquipment: '', announcement: '', version: 1 };
    let result = await command('create', event, form);
    equal(result.meetups[0].myStatus, 'approved', 'Creator is a member');
    await command('create', event, form);
    equal((await snapshot()).meetups.length, 1, 'Create retry is idempotent');
    await denied(() => db.query('select * from meetup_applications'), 'permission');
    await as(users[6]);
    equal((await snapshot()).meetups.length, 0, 'Demo does not see real activities');
    await denied(() => command('apply', event, { requestID: uuid(), fields: [], consent: false }), '找不到');
    await as(users[7]);
    await denied(() => command('apply', event, { requestID: uuid(), fields: [], consent: false }), '體型');
    await as(users[1]);
    await denied(() => command('apply', event, { requestID: uuid(), fields: ['basic'], consent: false }), '同意');
    const req1 = uuid();
    await command('apply', event, { requestID: req1, fields: ['basic','age','sex','reaction'], consent: true });
    await command('apply', event, { requestID: req1, fields: ['basic','age','sex','reaction'], consent: true });
    result = await snapshot();
    equal(result.meetups[0].myStatus, 'pending', 'Age/neuter/reaction do not auto-reject');
    equal(result.meetups[0].messages.length, 0, 'Pending cannot see messages');
    await denied(() => command('send', event, { messageID: uuid(), text: '不可傳送' }), '存取');
    await denied(() => command('review', event, { userID: users[1], status: 'approved', requestID: req1 }), '發起人');
    await as(users[0]);
    result = await snapshot();
    const applicant = result.meetups[0].members.find(m => m.userID === users[1]);
    equal(applicant.dog.neutered, false, 'Consented source data was copied');
    ok(!JSON.stringify(applicant).includes('health_answers'), 'Private health stays private');
    equal((await db.query('select meetup_can_review_photo($1) allowed',[`${users[1]}/photo.jpg`])).rows[0].allowed,true,'Host can read explicitly shared review photo');
    await command('review', event, { userID: users[1], status: 'approved', requestID: req1 });
    await as(users[1]);
    result = await snapshot();
    equal(result.meetups[0].myStatus, 'approved');
    equal((await db.query('select meetup_can_review_photo($1) allowed',[`${users[0]}/photo.jpg`])).rows[0].allowed,false,'Participant cannot read unrelated private photo');
    ok(!('neutered' in result.meetups[0].members.find(m => m.userID === users[1]).dog), 'Review data not broadcast to group');
    equal((await db.query('select meetup_checkin_eligible($1) result',[event])).rows[0].result, false, 'Rules required before check-in');
    await command('confirm', event, { section: 'rules', version: 1 });
    await command('confirm', event, { section: 'info', version: 1 });
    equal((await db.query('select meetup_checkin_eligible($1) result',[event])).rows[0].result, true, 'Rules only suffices');
    const msg = uuid(); await command('send', event, { messageID: msg, text: '大家好' });
    await command('send', event, { messageID: msg, text: '大家好' });
    equal((await snapshot()).meetups[0].messages.length, 1, 'No duplicate messages on retry');
    await command('mute', event, { muted: true });
    equal((await snapshot()).meetups[0].muted, true, 'Mute persists');
    await as(users[0]);
    equal((await snapshot()).meetups[0].unread, 1);
    await command('read'); equal((await snapshot()).meetups[0].unread, 0);
    await command('edit', event, { ...form, title: '更新集合資訊', version: 1 });
    await denied(() => command('edit', event, { ...form, version: 1 }), '已被更新');
    await as(users[1]);
    result = await snapshot();
    equal(result.meetups[0].rulesVersion, 1, 'Unchanged rules remain valid');
    equal(result.meetups[0].infoVersion, 2, 'Only edited section is invalidated');
    equal(result.meetups[0].confirmations.info, 1);
    await as(users[0]);
    await command('edit', event, { ...form, title: '更新集合資訊', venueRules: '場地補充', version: 2 });
    await as(users[1]);
    equal((await db.query('select meetup_checkin_eligible($1) result',[event])).rows[0].result, false, 'Stale rules must be reconfirmed');
    await denied(() => command('confirm', event, { section: 'rules', version: 1 }), '已更新');
    await command('leave');
    await denied(() => command('send', event, { messageID: uuid(), text: '退出後不可傳送' }), '存取');
    const req2 = uuid(); await command('apply', event, { requestID: req2, fields: [], consent: false });
    equal((await snapshot()).meetups[0].myStatus, 'pending', 'Rejoining requires approval');
    await as(users[0]);
    equal((await db.query('select meetup_can_review_photo($1) allowed',[`${users[1]}/photo.jpg`])).rows[0].allowed,false,'Reapplication without consent revokes old shared photo');
    await denied(() => command('review', event, { userID: users[1], status: 'approved', requestID: req1 }), '狀態');
    await command('review', event, { userID: users[1], status: 'approved', requestID: req2 });
    // Five distinct participants trigger review, never automatic ending.
    for (const user of users.slice(2,6)) {
        await as(user); const id = uuid(); await command('apply',event,{requestID:id,fields:[],consent:false});
        await as(users[0]); await command('review',event,{userID:user,status:'approved',requestID:id});
    }
    for (const user of users.slice(1,6)) { await as(user); await command('report',event,{reason:'需要檢查'}); await command('report',event,{reason:'重複'}); }
    await db.exec('reset role');
    equal((await db.query('select count(*)::int n from meetup_reports')).rows[0].n,5,'Unique reporters');
    equal((await db.query('select count(*)::int n from meetup_review_cases')).rows[0].n,1,'Review case created');
    await as(users[0]);
    equal((await snapshot()).meetups[0].status,'active','Reports do not auto-end');
    await denied(() => command('report',event,{reason:'主持人'}),'發起人');
    const endID=uuid(); await command('requestEnd',event,{requestID:endID});
    await denied(() => command('approveEnd',event,{requestID:endID}),'發起人');
    await as(users[1]); await command('approveEnd',event,{requestID:endID}); await command('approveEnd',event,{requestID:endID});
    equal((await snapshot()).meetups[0].status,'active','One person repeated cannot end');
    await as(users[2]); await command('approveEnd',event,{requestID:endID});
    result=await snapshot(); equal(result.meetups[0].status,'ended','Second distinct vote ends');
    equal(result.meetups[0].messages.filter(m=>m.senderID===null).length,1,'Immediate expiry reminder');
    await db.exec('reset role'); await db.query("update meetup_events set ended_at=now()-interval '13 days 1 hour' where id=$1",[event]);
    await as(users[1]); result=await snapshot();
    equal(result.meetups[0].messages.filter(m=>m.senderID===null).length,3,'End/3-day/1-day reminders');
    equal((await snapshot()).meetups[0].messages.filter(m=>m.senderID===null).length,3,'Reminders are idempotent');
    await db.exec('reset role'); await db.query("update meetup_events set ended_at=now()-interval '14 days' where id=$1",[event]);
    await as(users[1]); result=await snapshot();
    equal(result.meetups[0].status,'archived'); equal(result.meetups[0].messages.length,0,'Archived messages not accessible');
    await denied(()=>command('send',event,{messageID:uuid(),text:'逾期'}),'存取');
    await db.exec('reset role'); ok((await db.query('select count(*)::int n from meetup_messages')).rows[0].n>0,'Archive preserves backend data');
    await as(users[0]);
    await command('create',otherEvent,{...form,allowedSizes:[],capacity:2});
    await as(users[7]); const sizeRequest=uuid();
    await command('apply',otherEvent,{requestID:sizeRequest,fields:[],consent:false});
    await as(users[0]); await command('edit',otherEvent,{...form,capacity:2,version:1});
    await denied(()=>command('review',otherEvent,{userID:users[7],requestID:sizeRequest,status:'approved'}),'體型');
    const staleEnd=uuid(); await command('requestEnd',otherEvent,{requestID:staleEnd});
    await db.exec('reset role'); await db.query("update meetup_end_requests set expires_at=now()-interval '1 hour' where id=$1",[staleEnd]);
    await as(users[0]); equal((await snapshot(otherEvent)).meetups.find(m=>m.id===otherEvent).endApplication,null,'48-hour application expires');
    // No administrative capability leaks to authenticated users.
    await denied(()=>db.query('select review_meetup_case($1,true,$2,$3)',[event,'管理員','說明']),'permission');
    console.log(`PASS: ${tests} meetup database assertions (RPC permissions, consent, retries, revisions, D05 and retention).`);
} catch (error) {
    console.error(`FAIL after ${tests} assertions: ${error.message}`);
    console.error(error.detail ?? '');
    process.exitCode=1;
} finally { await db.close(); }
