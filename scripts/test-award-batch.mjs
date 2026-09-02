import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { test } from 'node:test'
import ts from 'typescript'

const source = await readFile(new URL('../src/lib/runBatch.ts', import.meta.url), 'utf8')
const { outputText } = ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 },
})
const { runBatch } = await import(`data:text/javascript;base64,${Buffer.from(outputText).toString('base64')}`)
const delay = ms => new Promise(resolve => setTimeout(resolve, ms))

test('limits concurrency, processes each student once and reports all progress', async () => {
  const students = Array.from({ length: 30 }, (_, i) => i)
  let active = 0
  let peak = 0
  const seen = []
  const progress = []
  const result = await runBatch(students, async id => {
    active++
    peak = Math.max(peak, active)
    await delay(3)
    seen.push(id)
    active--
  }, (completed, total) => progress.push([completed, total]))
  assert.equal(peak, 5)
  assert.equal(active, 0)
  assert.deepEqual(seen.sort((a, b) => a - b), students)
  assert.equal(result.succeeded.length, 30)
  assert.equal(result.failed.length, 0)
  assert.deepEqual(progress, students.map(i => [i + 1, 30]))
})

test('waits for in-flight writes and retains successes when another student fails', async () => {
  const failure = new Error('write failed')
  const finished = []
  const result = await runBatch([0, 1, 2, 3, 4, 5, 6], async id => {
    if (id === 1) throw failure
    await delay(id === 0 ? 25 : 2)
    finished.push(id)
  })
  assert.deepEqual(result.failed, [{ item: 1, error: failure }])
  assert.deepEqual(result.succeeded.sort(), [0, 2, 3, 4, 5, 6])
  assert.equal(finished.length, 6)
})

test('empty batch does not write anything', async () => {
  const result = await runBatch([], async () => assert.fail('unexpected write'))
  assert.deepEqual(result, { succeeded: [], failed: [] })
})

test('simulated 30-student latency comparison (not production timing)', async () => {
  const students = Array.from({ length: 30 }, (_, i) => i)
  const write = async () => { await delay(20); await delay(20) }
  let start = performance.now()
  for (const student of students) await write(student)
  const serialMs = performance.now() - start
  start = performance.now()
  await runBatch(students, write)
  const concurrentMs = performance.now() - start
  console.log(`Simulated 30 students: serial ${serialMs.toFixed(0)} ms, concurrent ${concurrentMs.toFixed(0)} ms`)
})
