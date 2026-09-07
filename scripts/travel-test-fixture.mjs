import { readFile } from 'node:fs/promises'
import { pathToFileURL } from 'node:url'
import { randomUUID } from 'node:crypto'
export async function createFixture({ tickets = false } = {}) {
  const { PGlite } = await import(process.env.PGLITE_MODULE ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite')
  const db = new PGlite()
  const schema = await readFile(new URL('../supabase-schema.sql', import.meta.url), 'utf8')
  await db.exec('CREATE ROLE anon; CREATE ROLE authenticated;')
  await db.exec(schema.slice(0, schema.indexOf('-- RLS 策略')).replace(/-- =+\s*$/, ''))
  await db.exec(await readFile(new URL('../supabase-migration-shop.sql', import.meta.url), 'utf8'))
  const migration = await readFile(new URL('../supabase-migration-travel.sql', import.meta.url), 'utf8')
  await db.exec(migration)
  await db.exec(migration)
  if (tickets) {
    await db.exec(await readFile(new URL('../supabase-migration-classroom.sql', import.meta.url), 'utf8'))
    const ticketMigration = await readFile(new URL('../supabase-migration-travel-tickets.sql', import.meta.url), 'utf8')
    await db.exec(ticketMigration)
    await db.exec(ticketMigration)
    const historyMigration = await readFile(new URL('../supabase-migration-travel-ticket-history.sql', import.meta.url), 'utf8')
    await db.exec(historyMigration)
    await db.exec(historyMigration)
    const spendingMigration = await readFile(new URL('../supabase-migration-point-spending-history.sql', import.meta.url), 'utf8')
    await db.exec(spendingMigration)
    await db.exec(spendingMigration)
    const ledgerMigration = await readFile(new URL('../supabase-migration-student-ledger.sql', import.meta.url), 'utf8')
    await db.exec(ledgerMigration)
    await db.exec(ledgerMigration)
  }
  const student = randomUUID(), other = randomUUID(), teacher = randomUUID(), pet = randomUUID(), otherPet = randomUUID()
  await db.query(`INSERT INTO profiles(id,username,password,role,points) VALUES ($1,'旅行同学','test','student',100),($2,'另一位同学','test','student',100),($3,'旅行老师','test','teacher',0)`, [student, other, teacher])
  await db.query('UPDATE profiles SET teacher_id=$1 WHERE id=$2', [teacher, student])
  await db.query(`INSERT INTO pets(id,owner_id,name,species,appearance) VALUES ($1,$2,'小云','云朵猫','{"color":"#c9dcec"}'),($3,$4,'小海','碧海龟','{}')`, [pet, student, otherPet, other])
  const scalar = async (sql, args = []) => Object.values((await db.query(sql, args)).rows[0])[0]
  return { db, scalar, student, other, teacher, pet, otherPet, schema, migration }
}

// PostgreSQL 自带随机数种子：控制真实结算分支，不替换业务函数。
export async function seedDrop(db, wanted) {
  for (let n = 0; n < 2000; n++) {
    const seed = n / 2000
    await db.query('SELECT setseed($1)', [seed])
    await db.query('SELECT random()')
    const drop = (await db.query('SELECT random() AS value')).rows[0].value < .01
    if (drop === wanted) { await db.query('SELECT setseed($1)', [seed]); return }
  }
  throw new Error('No random seed found')
}
