import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { pathToFileURL } from 'node:url'
import { randomUUID } from 'node:crypto'
const { PGlite } = await import(process.env.PGLITE_MODULE ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite')
const db = new PGlite()
const schema = await readFile(new URL('../supabase-schema.sql',import.meta.url),'utf8')
const migration = await readFile(new URL('../supabase-migration-revoke-awards.sql',import.meta.url),'utf8')
assert.ok(schema.replaceAll('\r\n','\n').trimEnd().endsWith(migration.replaceAll('\r\n','\n').trimEnd()))
await db.exec('CREATE ROLE anon; CREATE ROLE authenticated;')
await db.exec(schema.slice(0,schema.indexOf('-- RLS 策略')).replace(/-- =+\s*$/,''))
await db.exec(await readFile(new URL('../supabase-migration-classroom.sql',import.meta.url),'utf8'))
await db.exec(migration)
await db.exec(migration)
const teacher=randomUUID(), other=randomUUID(), student=randomUUID(), task=randomUUID(), award=randomUUID()
await db.query(`INSERT INTO profiles(id,username,password,role,points,teacher_id) VALUES
($1,'老师','test','teacher',0,NULL),($2,'其他老师','test','teacher',0,NULL),($3,'同学','test','student',5,$1)`,[teacher,other,student])
await db.query(`INSERT INTO tasks(id,name,points,created_by) VALUES($1,'任务',10,$2)`,[task,teacher])
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0]
const give=(id=award)=>scalar('SELECT award_task_points($1,$2,$3,$4)',[teacher,student,task,id])
const revoke=(reason='重复发放',actor=teacher,id=award)=>scalar('SELECT revoke_task_award($1,$2,$3)',[actor,id,reason])
await give()
await assert.rejects(revoke('',teacher),/撤销原因/)
await assert.rejects(revoke('误发',other),/本班/)
await assert.rejects(revoke('误发',student),/本班/)
// Failure during metadata write must roll back the preceding balance change.
await db.exec(`CREATE FUNCTION fail_revoke() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'forced metadata failure'; END $$;
CREATE TRIGGER fail_revoke BEFORE UPDATE ON task_completions FOR EACH ROW EXECUTE FUNCTION fail_revoke();`)
await assert.rejects(revoke(),/forced metadata failure/)
assert.equal(await scalar('SELECT points FROM profiles WHERE id=$1',[student]),15)
await db.exec('DROP TRIGGER fail_revoke ON task_completions')
const result=await revoke()
assert.equal(result.balance,5)
assert.equal(result.completion.revoke_reason,'重复发放')
assert.equal(result.completion.revoked_by,teacher)
assert.ok(result.completion.revoked_at)
assert.equal((await revoke('其他原因')).alreadyRevoked,true)
assert.equal(await scalar('SELECT points FROM profiles WHERE id=$1',[student]),5)
assert.equal((await give()).balance,5,'retrying original award never reissues revoked points')
assert.equal(await scalar('SELECT count(*)::int FROM point_earnings'),1,'original ledger preserved')
assert.equal(await scalar('SELECT points FROM task_completions WHERE id=$1',[award]),10)
assert.equal(await scalar('SELECT teacher_award_total($1)',[teacher]),0)
assert.equal((await scalar('SELECT weekly_leaderboard($1)',[teacher])).entries[0].points,0)
// Insufficient balance leaves everything untouched; disabled tasks can still be corrected.
const second=randomUUID(); await give(second)
await db.query('UPDATE profiles SET points=3 WHERE id=$1',[student])
await assert.rejects(revoke('发错了',teacher,second),/余额/)
assert.equal(await scalar('SELECT revoked_at FROM task_completions WHERE id=$1',[second]),null)
await db.query('UPDATE profiles SET points=10 WHERE id=$1',[student])
await db.query('UPDATE tasks SET is_active=false WHERE id=$1',[task])
await db.exec(`ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY read_profile ON profiles FOR SELECT USING (true);
CREATE POLICY update_profile ON profiles FOR UPDATE USING (true);
ALTER TABLE task_completions ENABLE ROW LEVEL SECURITY;
CREATE POLICY read_completion ON task_completions FOR SELECT USING (true);
GRANT SELECT,UPDATE ON profiles TO anon; GRANT SELECT ON task_completions TO anon; SET ROLE anon;`)
assert.equal((await revoke('任务停用前误发',teacher,second)).balance,0)
await db.exec('RESET ROLE;')
await db.exec(migration)
assert.equal(await scalar('SELECT teacher_award_total($1)',[teacher]),0)
assert.equal((await scalar('SELECT weekly_leaderboard($1)',[teacher])).entries[0].points,0)
console.log('PASS: revoke atomic rollback, repeat/retry, author and class checks, reason validation, insufficient funds, original records preserved, disabled tasks, ranking, totals, anon role and migration replay.')
await db.close()
