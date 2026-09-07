import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { randomUUID } from 'node:crypto'
import { createFixture } from './travel-test-fixture.mjs'

const { db, scalar, student, teacher, pet, otherPet, schema } = await createFixture({ tickets: true })
const migration = await readFile(new URL('../supabase-migration-travel-care.sql', import.meta.url), 'utf8')
await db.exec(migration)
await db.exec(migration)
await db.query("UPDATE pets SET hunger=80,last_fed_at=now()-interval '2 hours' WHERE id=$1", [pet])
await db.query('INSERT INTO travel_wallets(user_id,tickets) VALUES($1,2)', [student])
const trip = await scalar('SELECT start_pet_trip($1,$2,$3,$4)', [student, pet, 'forest', randomUUID()])
assert.equal(await scalar('SELECT hunger FROM pets WHERE id=$1', [pet]), 77)
const snapshot = await scalar('SELECT row_to_json(p) FROM pets p WHERE id=$1', [pet])
await db.exec(migration)
assert.deepEqual(await scalar('SELECT row_to_json(p) FROM pets p WHERE id=$1', [pet]), snapshot)
for (const actor of [student, teacher]) for (const food of ['basic', 'nice', 'luxury']) {
  await assert.rejects(scalar('SELECT feed_pet($1,$2,$3,$4,$5)', [actor, student, pet, food, randomUUID()]), /旅行中/)
}
assert.equal(await scalar('SELECT points FROM profiles WHERE id=$1', [student]), 100)
assert.equal(await scalar('SELECT count(*) FROM feeding_events'), 0)
assert.deepEqual(await scalar('SELECT row_to_json(p) FROM pets p WHERE id=$1', [pet]), snapshot)
assert.equal(await scalar('SELECT hunger_paused_until FROM pets WHERE id=$1', [otherPet]), null)
// Simulate return two hours ago without claiming. Only post-return hunger decays.
await db.query("UPDATE pet_trips SET started_at=now()-interval '6 hours',returns_at=now()-interval '2 hours' WHERE id=$1", [trip.id])
await db.query("UPDATE pets SET last_fed_at=now()-interval '8 hours',hunger_paused_until=now()-interval '2 hours' WHERE id=$1", [pet])
const request = randomUUID()
const result = await scalar('SELECT feed_pet($1,$2,$3,$4,$5)', [teacher, student, pet, 'basic', request])
assert.equal(result.pet.hunger, 99)
assert.equal(result.points, 95)
assert.deepEqual(await scalar('SELECT feed_pet($1,$2,$3,$4,$5)', [teacher, student, pet, 'basic', request]), result)
const fresh = new db.constructor()
await fresh.exec('CREATE ROLE anon; CREATE ROLE authenticated; CREATE SCHEMA storage; CREATE TABLE storage.buckets(id text primary key,name text,public boolean); CREATE TABLE storage.objects(bucket_id text);')
await fresh.exec(schema)
await fresh.query('SELECT hunger_paused_until FROM pets')
await fresh.close()
await db.close()
console.log('PASS: departure settlement, migration repeatability, student/teacher feeding blocked without charges, independent pets, return decay and feeding retry')
