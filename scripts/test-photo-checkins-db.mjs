// Isolated PostgreSQL tests; never connects to the deployed Supabase project.
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { pathToFileURL } from 'node:url'
import { randomUUID } from 'node:crypto'
const { PGlite } = await import(process.env.PGLITE_MODULE ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite')
const db = new PGlite()
try {
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
    CREATE SCHEMA storage; CREATE TABLE storage.buckets(id text PRIMARY KEY,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);`)
  const schema = await readFile(new URL('../supabase-schema.sql', import.meta.url), 'utf8')
  await db.exec(schema.slice(0, schema.indexOf('-- RLS 策略')).replace(/-- =+\s*$/, ''))
  await db.exec(await readFile(new URL('../supabase-migration-classroom.sql', import.meta.url), 'utf8'))
  await db.exec(await readFile(new URL('../supabase-migration-revoke-awards.sql', import.meta.url), 'utf8'))
  const migration = await readFile(new URL('../supabase-migration-photo-checkins.sql', import.meta.url), 'utf8')
  assert.ok(schema.replaceAll('\r\n', '\n').includes(migration.replaceAll('\r\n', '\n').trim()), 'fresh schema includes the same migration')
  await db.exec(migration); await db.exec(migration)
  const scalar = async (sql, args = []) => Object.values((await db.query(sql, args)).rows[0])[0]
  const teacher = randomUUID(), otherTeacher = randomUUID(), student = randomUUID(), otherStudent = randomUUID()
  await db.query(`INSERT INTO profiles(id,username,password,role,teacher_id) VALUES
    ($1,'照片老师','test','teacher',NULL),($2,'其他老师','test','teacher',NULL),
    ($3,'照片学生','test','student',$1),($4,'其他学生','test','student',$2)`, [teacher, otherTeacher, student, otherStudent])
  const reserve = (id, actor = student, size = 1234) => scalar('SELECT to_jsonb(reserve_photo_checkin($1,$2,$3,$4))', [actor, id, size, '整理书桌'])
  const finish = (id, actor = student) => scalar('SELECT to_jsonb(finish_photo_checkin($1,$2))', [actor, id])
  const review = (id, points = 12, actor = teacher) => scalar('SELECT to_jsonb(review_photo_checkin($1,$2,$3,$4))', [actor, id, points, '继续努力'])
  const ids = [randomUUID(), randomUUID(), randomUUID()]
  await Promise.all(ids.map(id => reserve(id)))
  await assert.rejects(reserve(randomUUID()), /三张/)
  await finish(ids[0]); await finish(ids[0])
  assert.equal(await scalar('SELECT count(*)::int FROM photo_checkins WHERE submitted_at IS NOT NULL'), 1)
  await assert.rejects(finish(ids[0], otherStudent), /不存在/)
  await assert.rejects(review(ids[0], 12, otherTeacher), /本班/)
  await assert.rejects(review(ids[0], -1), /积分/)
  await assert.rejects(review(ids[0], null), /积分/)
  await Promise.all([review(ids[0]), review(ids[0])])
  assert.equal(await scalar('SELECT points FROM profiles WHERE id=$1', [student]), 12)
  assert.equal(await scalar('SELECT count(*)::int FROM task_completions WHERE id=$1', [ids[0]]), 1)
  assert.equal(await scalar('SELECT points FROM point_earnings WHERE source_id=$1', ['task:' + ids[0]]), 12)
  await assert.rejects(review(ids[0], 15), /已审核/)
  await finish(ids[1]); await review(ids[1], 0)
  assert.equal(await scalar('SELECT points FROM profiles WHERE id=$1', [student]), 12)
  await finish(ids[2])
  await db.exec(`CREATE FUNCTION fail_photo_earning() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'forced earning failure'; END $$;
    CREATE TRIGGER fail_photo_earning BEFORE INSERT ON point_earnings FOR EACH ROW EXECUTE FUNCTION fail_photo_earning();`)
  await assert.rejects(review(ids[2]), /forced earning failure/)
  assert.equal(await scalar('SELECT points FROM profiles WHERE id=$1', [student]), 12)
  assert.equal(await scalar('SELECT status FROM photo_checkins WHERE id=$1', [ids[2]]), 'pending')
  assert.equal(await scalar('SELECT count(*)::int FROM task_completions WHERE id=$1', [ids[2]]), 0)
  await db.exec('DROP TRIGGER fail_photo_earning ON point_earnings')
  await scalar('SELECT revoke_task_award($1,$2,$3)', [teacher, ids[0], '测试撤销'])
  assert.equal(await scalar('SELECT points FROM profiles WHERE id=$1', [student]), 0)
  await review(ids[0]) // A retry cannot re-award a revoked completion.
  assert.equal(await scalar('SELECT points FROM profiles WHERE id=$1', [student]), 0)
  await db.query(`UPDATE photo_checkins SET expires_at=now()-interval '1 second' WHERE id=ANY($1::uuid[])`, [ids])
  await assert.rejects(review(ids[2]), /过期/)
  assert.equal((await db.query('SELECT * FROM claim_expired_photo_checkins()')).rows.length, 3)
  assert.equal((await db.query('SELECT * FROM claim_expired_photo_checkins()')).rows.length, 3, 'failed object deletion stays retryable')
  await db.exec('UPDATE photo_checkins SET photo_deleted_at=now()')
  assert.equal((await db.query('SELECT * FROM claim_expired_photo_checkins()')).rows.length, 0)
  await assert.rejects(reserve(randomUUID()), /三张/, 'photo deletion does not reset the daily quota')
  // Beijing date rollover: yesterday does not consume today; pending reservations still do.
  await db.exec(`UPDATE photo_checkins SET submission_day=(now() AT TIME ZONE 'Asia/Shanghai')::date-1`)
  const rollover = randomUUID(); await reserve(rollover); await finish(rollover)
  assert.equal(await scalar('SELECT submission_day=(now() AT TIME ZONE \'Asia/Shanghai\')::date FROM photo_checkins WHERE id=$1', [rollover]), true)
  await db.exec('UPDATE photo_checkin_settings SET max_bytes=1234')
  await assert.rejects(reserve(randomUUID(), otherStudent), /空间/)
  await db.exec(`SET ROLE anon`)
  await assert.rejects(db.query('SELECT * FROM photo_checkins'), /permission denied/)
  await assert.rejects(reserve(randomUUID()), /permission denied/)
  await assert.rejects(db.query('SELECT * FROM photo_checkin_sessions'), /permission denied/)
  await db.exec('RESET ROLE')
  assert.equal(await scalar("SELECT public FROM storage.buckets WHERE id='photo-checkins'"), false)
  for (let i = 0; i < 10; i++) assert.equal(await scalar('SELECT photo_checkin_login_attempt($1)', [student]), true)
  assert.equal(await scalar('SELECT photo_checkin_login_attempt($1)', [student]), false)
  console.log('PASS: migration rerun, daily quota/reservations, Beijing dates, capacity, ownership, atomic reward/rollback, retry/revocation, cleanup retry, private permissions, login throttle')
} finally { await db.close() }
