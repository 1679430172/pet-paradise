// PGLITE_MODULE may point to an external @electric-sql/pglite/dist/index.js.
// Runs the actual migration in an isolated PostgreSQL WASM database, never production.
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { pathToFileURL } from 'node:url'
import { randomUUID } from 'node:crypto'
const { PGlite } = await import(process.env.PGLITE_MODULE ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite')
const db = new PGlite()
const schema = await readFile(new URL('../supabase-schema.sql', import.meta.url), 'utf8')
const migration = await readFile(new URL('../supabase-migration-classroom.sql', import.meta.url), 'utf8')
assert.ok(schema.replaceAll('\r\n','\n').trimEnd().includes(migration.replaceAll('\r\n','\n').trimEnd()), 'fresh install includes the exact migration')
await db.exec('CREATE ROLE anon; CREATE ROLE authenticated;')
await db.exec(schema.slice(0, schema.indexOf('-- RLS 策略')).replace(/-- =+\s*$/, ''))
const teacher = randomUUID(), otherTeacher = randomUUID(), student = randomUUID(), otherStudent = randomUUID()
const pet = randomUUID(), otherPet = randomUUID(), task = randomUUID(), historical = randomUUID()
await db.query(`INSERT INTO profiles(id,username,password,role,points,teacher_id) VALUES
  ($1,'老师','test','teacher',0,NULL),($2,'其他老师','test','teacher',0,NULL),
  ($3,'小明','test','student',100,$1),($4,'小红','test','student',100,$2)`, [teacher, otherTeacher, student, otherStudent])
await db.query(`INSERT INTO pets(id,owner_id,name,species,hunger,xp,level) VALUES
  ($1,$2,'小紫','紫电龙',100,14,1),($3,$4,'小狐','星焰狐',100,0,1)`,[pet,student,otherPet,otherStudent])
await db.query(`INSERT INTO tasks(id,name,points,created_by) VALUES($1,'认真听讲',10,$2)`,[task,teacher])
await db.query(`INSERT INTO task_completions(id,task_id,student_id,awarded_by,points) VALUES($1,$2,$3,$4,10)`,[historical,task,student,teacher])
await db.exec(migration)
await db.exec(migration)
const scalar = async (sql, args = []) => Object.values((await db.query(sql,args)).rows[0])[0]
const feed = (actor = teacher, who = student, target = pet, action = 'basic', request = randomUUID()) =>
  scalar('SELECT feed_pet($1,$2,$3,$4,$5)',[actor,who,target,action,request])
const board = () => scalar('SELECT weekly_leaderboard($1)',[teacher])
assert.equal(await scalar('SELECT count(*)::int FROM point_earnings'),1,'migration backfill is idempotent')
const id = randomUUID()
const first = await feed(student,student,pet,'basic',id)
assert.equal(first.points,95)
assert.equal(first.pet.hunger,100,'full pets can still eat')
assert.equal(first.pet.xp,22)
assert.equal(first.pet.level,2)
assert.equal(first.leveledUp,true)
assert.deepEqual(await feed(student,student,pet,'basic',id),first,'same request returns same result')
assert.equal(await scalar('SELECT points FROM profiles WHERE id=$1',[student]),95,'no double charge')
await assert.rejects(feed(student,student,pet,'nice',id),/请求编号/)
await assert.rejects(feed(otherTeacher),/本人或本班/)
await assert.rejects(feed(teacher,student,otherPet),/宠物不存在/)
await assert.rejects(feed(teacher,student,pet,'unknown'),/无效/)
// Fail the last write: both preceding balance and pet updates must roll back.
await db.exec(`CREATE FUNCTION fail_feed_event() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'forced audit failure'; END $$;
CREATE TRIGGER fail_event BEFORE INSERT ON feeding_events FOR EACH ROW EXECUTE FUNCTION fail_feed_event();`)
await assert.rejects(feed(),/forced audit failure/)
assert.equal(await scalar('SELECT points FROM profiles WHERE id=$1',[student]),95)
assert.equal(await scalar('SELECT xp FROM pets WHERE id=$1',[pet]),22)
await db.exec('DROP TRIGGER fail_event ON feeding_events')
await db.query('UPDATE profiles SET points=0 WHERE id=$1',[student])
await assert.rejects(feed(),/积分不足/)
assert.equal(await scalar('SELECT xp FROM pets WHERE id=$1',[pet]),22)
const awardId = randomUUID()
const award = () => scalar('SELECT award_task_points($1,$2,$3,$4)',[teacher,student,task,awardId])
assert.equal((await award()).balance,10)
assert.equal((await award()).balance,10)
assert.equal(await scalar('SELECT count(*)::int FROM task_completions'),2)
await db.exec(`CREATE FUNCTION fail_earning() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'forced earning failure'; END $$;
CREATE TRIGGER fail_earning BEFORE INSERT ON point_earnings FOR EACH ROW EXECUTE FUNCTION fail_earning();`)
await assert.rejects(scalar('SELECT award_task_points($1,$2,$3,$4)',[teacher,student,task,randomUUID()]),/forced earning failure/)
assert.equal(await scalar('SELECT count(*)::int FROM task_completions'),2,'award record also rolls back')
assert.equal(await scalar('SELECT points FROM profiles WHERE id=$1',[student]),10)
await db.exec('DROP TRIGGER fail_earning ON point_earnings')
await assert.rejects(scalar('SELECT award_task_points($1,$2,$3,$4)',[teacher,otherStudent,task,randomUUID()]),/本班/)
const beforeBoard = await board()
await feed()
assert.equal((await board()).entries[0].points,beforeBoard.entries[0].points,'spending never reduces weekly score')
const diaryId = randomUUID()
const diary = (id) => scalar('SELECT publish_diary($1,$2,$3,$4)',[student,pet,{title:'今天',content:'小紫长大啦'},id])
const published = await diary(diaryId)
assert.equal(published.reward,5)
assert.equal((await diary(diaryId)).reward,5,'retry returns original reward without writing again')
assert.equal((await diary(randomUUID())).reward,0,'second diary does not earn')
await db.query('DELETE FROM diary_entries WHERE owner_id=$1',[student])
assert.equal((await diary(randomUUID())).reward,0,'deleting entries cannot reclaim daily reward')
assert.equal(await scalar('SELECT xp FROM pets WHERE id=$1',[pet]),30,'diaries add no XP')
// Include >50 students, tied scores and a zero-income student. Check exact China week boundaries.
await db.query(`INSERT INTO profiles(username,password,role,teacher_id) SELECT '同学'||n,'test','student',$1 FROM generate_series(1,60) n`,[teacher])
const week = (await board()).weekStart
await db.query(`INSERT INTO point_earnings(source_id,student_id,teacher_id,points,reason,created_at) VALUES
  ('before-week',$1,$2,999,'上周',$3::timestamptz - interval '1 millisecond'),
  ('at-week',$1,$2,7,'本周',$3::timestamptz),
  ('after-week',$1,$2,999,'下周',$3::timestamptz + interval '7 days'),
  ('other-class',$1,$4,999,'其他班级',$3::timestamptz)`,[student,teacher,week,otherTeacher])
const ranking = await board()
assert.equal(ranking.entries.length,61)
assert.equal(ranking.entries[0].points,32,'20 task + 5 diary + 7 at week start')
assert.equal(ranking.entries.at(-1).rank,null)
assert.equal(new Date(week).getUTCDay(),0)
assert.equal(new Date(week).getUTCHours(),16,'Monday midnight Shanghai is Sunday 16:00 UTC')
const tieStudent = ranking.entries[1].id
await db.query(`INSERT INTO point_earnings(source_id,student_id,teacher_id,points,reason) VALUES('tie',$1,$2,32,'同分')`,[tieStudent,teacher])
assert.deepEqual((await board()).entries.slice(0,2).map(e => e.rank),[1,1])
await db.exec(migration)
assert.equal((await board()).entries.find(e => e.id===student).points,32,'rerun does not duplicate new awards')
// Exercise both supported roles under the project's existing open-policy model.
await db.exec('GRANT SELECT,INSERT,UPDATE ON profiles,pets,tasks,task_completions,diary_entries,settings TO anon; SET ROLE anon;')
assert.equal((await feed()).cost,5)
await db.exec('RESET ROLE;')
console.log('PASS: migration replay, feed atomic rollback, award atomic rollback, duplicate requests, ownership, funds, full-hunger feeding, diary daily reward, weekly boundaries, ties, >50 students, anonymous-role RPC.')
await db.close()
