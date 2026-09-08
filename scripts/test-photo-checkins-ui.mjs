// Real Vue UI against an isolated, deterministic Edge Function fixture.
// Database rules are separately exercised by test-photo-checkins-db.mjs.
import assert from 'node:assert/strict'
import { mkdir } from 'node:fs/promises'
import { pathToFileURL } from 'node:url'
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE ? pathToFileURL(process.env.PLAYWRIGHT_MODULE).href : 'playwright')
const browser = await chromium.launch({ channel: process.env.BROWSER_CHANNEL || 'chrome', headless: true })
const artifacts = process.env.ARTIFACT_DIR || 'node_modules/.checkin-test/screenshots'
await mkdir(artifacts, { recursive: true })
const teacherId = '11111111-1111-4111-8111-111111111111', studentId = '22222222-2222-4222-8222-222222222222'
const rows = []; let todayCount = 0; let uploadCalls = 0; let reviewCalls = 0; let failNextList = false
const errors = []
async function createPage(teacher) {
  const profile = { id: teacher ? teacherId : studentId, username: teacher ? '林老师' : '陈小雨', role: teacher ? 'teacher' : 'student', points: 0, teacher_id: teacher ? null : teacherId, class_name: '向日葵一班', is_admin: false }
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } })
  page.on('pageerror', error => errors.push(error.message))
  await page.addInitScript(profile => localStorage.setItem('pet_user_id', profile.id), profile)
  await page.route('https://fonts.googleapis.com/**', route => route.fulfill({ contentType: 'text/css', body: '' }))
  await page.route('**/rest/v1/profiles*', route => {
    const params = new URL(route.request().url()).searchParams
    return route.fulfill({ contentType: 'application/json', body: JSON.stringify(params.has('id') ? profile : params.has('username') ? [profile] : []) })
  })
  await page.route('**/rest/v1/settings*', route => route.fulfill({ contentType: 'application/json', body: JSON.stringify({ value: { enabled: false } }) }))
  await page.route('**/functions/v1/photo-checkins', async route => {
    const request = route.request(); const data = request.postDataJSON()
    const send = (body, status = 200) => route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) })
    if (data.action === 'login') return data.password === 'test-password' ? send({ token: 'test-token' }) : send({ error: '密码错误' }, 401)
    if (request.headers()['x-checkin-token'] !== 'test-token') return send({ error: '请验证当前账号密码' }, 401)
    if (data.action === 'list') {
      if (failNextList) { failNextList = false; return send({ error: '测试加载失败' }, 500) }
      const selected = rows.filter(r => !data.status || r.status === data.status)
      return send({ entries: selected, total: selected.length, todayCount, urgentCount: teacher ? selected.filter(r => r.status === 'pending').length : 0, students: [{ id: studentId, username: '陈小雨', class_name: '向日葵一班' }] })
    }
    if (data.action === 'upload') {
      uploadCalls++
      assert.ok(Buffer.from(data.image, 'base64').length <= 204800)
      if (todayCount >= 3) return send({ error: '今天已上传三张照片' }, 400)
      todayCount++
      rows.unshift({ id: data.id, student_id: studentId, student_name: '陈小雨', class_name: '向日葵一班', description: data.description, status: 'pending', points: 0, feedback: '', submitted_at: new Date().toISOString(), expires_at: new Date(Date.now() + 86400000).toISOString(), image_url: 'data:image/jpeg;base64,' + data.image, image_error: false, revoked: false, photo_deleted_at: null })
      return send({ ok: true })
    }
    if (data.action === 'review') {
      reviewCalls++; const row = rows.find(r => r.id === data.id)
      assert.equal(row.status, 'pending')
      row.status = data.points ? 'awarded' : 'rejected'; row.points = data.points; row.feedback = data.feedback
      return send({ ok: true })
    }
    throw Error('Unexpected action ' + data.action)
  })
  await page.goto((process.env.APP_URL || 'http://127.0.0.1:5193') + (teacher ? '/#/teacher/checkins' : '/#/checkins'))
  await page.getByPlaceholder('请输入账号名').fill(profile.username)
  await page.getByPlaceholder('请输入密码').fill('test-password')
  await page.getByRole('button', { name: '登录', exact: true }).click()
  await page.getByRole('button', { name: '刷新记录' }).waitFor()
  assert.equal(await page.locator('input[type=password]').count(), 0, 'checkins has no separate password prompt')
  await page.reload()
  await page.getByRole('button', { name: '刷新记录' }).waitFor()
  assert.equal(await page.locator('input[type=password]').count(), 0, 'existing session survives page reload')
  return page
}
try {
  const student = await createPage(false)
  await student.waitForFunction(() => document.querySelector('input[type=file]') && !document.querySelector('input[type=file]').disabled)
  const image = await student.evaluate(() => {
    const canvas = document.createElement('canvas'); canvas.width = 2200; canvas.height = 1600
    const ctx = canvas.getContext('2d'); ctx.fillStyle = '#d4e5d3'; ctx.fillRect(0, 0, 2200, 1600)
    ctx.fillStyle = '#845d43'; ctx.fillRect(200, 900, 1800, 150); ctx.fillStyle = '#fff8e9'; ctx.fillRect(600, 500, 950, 400)
    ctx.fillStyle = '#315642'; ctx.font = 'bold 100px sans-serif'; ctx.fillText('今天读了二十分钟书', 620, 710)
    return canvas.toDataURL('image/png').split(',')[1]
  })
  for (let i = 0; i < 3; i++) {
    await student.getByLabel('选择一张打卡照片').setInputFiles({ name: 'reading.png', mimeType: 'image/png', buffer: Buffer.from(image, 'base64') })
    await student.getByRole('button', { name: '提交打卡', exact: true }).waitFor()
    await student.getByLabel('说说你完成了什么（选填）').fill(['今天读了二十分钟书，认识了三个新字。', '整理好自己的书桌。', '帮妈妈浇花。'][i])
    await student.getByRole('button', { name: '提交打卡', exact: true }).click()
    await student.getByText(`今日 ${i + 1}/3`).waitFor()
  }
  assert.equal(uploadCalls, 3)
  assert.equal(await student.getByLabel('选择一张打卡照片').isDisabled(), true)
  await student.screenshot({ path: `${artifacts}/student-desktop.png`, fullPage: true })
  await student.setViewportSize({ width: 390, height: 844 })
  assert.equal(await student.evaluate(() => document.documentElement.scrollWidth > innerWidth), false)
  await student.screenshot({ path: `${artifacts}/student-mobile.png`, fullPage: true })
  const teacher = await createPage(true)
  await teacher.getByRole('button', { name: '查看并审核 →' }).first().waitFor()
  await teacher.screenshot({ path: `${artifacts}/teacher-desktop.png`, fullPage: true })
  await teacher.getByRole('button', { name: '查看并审核 →' }).first().click()
  await teacher.getByLabel('奖励积分', { exact: true }).fill('15')
  await teacher.getByLabel('给学生的反馈（选填）').fill('很棒，继续保持！')
  await teacher.getByRole('button', { name: '全屏放大照片' }).click()
  const viewer = teacher.getByRole('dialog', { name: '照片全屏预览' })
  await viewer.waitFor()
  assert.ok((await viewer.boundingBox()).width >= 1438)
  await teacher.getByRole('button', { name: '放大照片', exact: true }).click()
  await teacher.getByText('150%', { exact: true }).waitFor()
  const fullPhoto = teacher.getByAltText('打卡照片全屏预览')
  await teacher.mouse.move(600, 400); await teacher.mouse.down(); await teacher.mouse.move(700, 450); await teacher.mouse.up()
  assert.ok((await fullPhoto.getAttribute('style')).includes('translate(100px, 50px)'))
  await teacher.screenshot({ path: `${artifacts}/photo-fullscreen-desktop.png` })
  await teacher.keyboard.press('Escape')
  assert.equal(await teacher.getByLabel('奖励积分', { exact: true }).inputValue(), '15')
  assert.equal(await teacher.getByLabel('给学生的反馈（选填）').inputValue(), '很棒，继续保持！')
  await teacher.setViewportSize({ width: 390, height: 844 })
  await teacher.getByRole('button', { name: '全屏放大照片' }).click()
  await teacher.getByRole('button', { name: '放大照片', exact: true }).click()
  assert.equal(await teacher.evaluate(() => document.documentElement.scrollWidth > innerWidth), false)
  await teacher.screenshot({ path: `${artifacts}/photo-fullscreen-mobile.png` })
  await teacher.getByRole('button', { name: '关闭大图' }).click()
  const bounds = await teacher.locator('dialog.checkin-dialog').boundingBox()
  assert.ok(Math.abs(bounds.x + bounds.width / 2 - 195) < 2, 'review dialog is horizontally centered')
  await teacher.screenshot({ path: `${artifacts}/teacher-review-mobile.png`, fullPage: true })
  await teacher.getByRole('button', { name: '确认发放积分' }).click()
  await teacher.getByText('已发放 15 积分。').waitFor()
  await teacher.getByRole('button', { name: '查看并审核 →' }).first().click()
  await teacher.getByRole('button', { name: '不给积分', exact: true }).click()
  await teacher.getByText('已审核，本次不发放积分。').waitFor()
  assert.equal(reviewCalls, 2)
  await teacher.getByLabel('审核状态').selectOption('awarded')
  await teacher.getByText('已奖励 +15', { exact: true }).waitFor()
  await teacher.setViewportSize({ width: 768, height: 1024 })
  assert.equal(await teacher.evaluate(() => document.documentElement.scrollWidth > innerWidth), false)
  await teacher.screenshot({ path: `${artifacts}/teacher-tablet.png`, fullPage: true })
  await student.getByRole('button', { name: '刷新记录' }).click()
  await student.getByText('已奖励 +15', { exact: true }).waitFor()
  failNextList = true
  await student.getByRole('button', { name: '刷新记录' }).click()
  await student.getByText('记录加载失败，请点击“刷新记录”重试。').waitFor()
  await student.getByRole('button', { name: '刷新记录' }).click()
  await student.getByText('已奖励 +15', { exact: true }).waitFor()
  assert.deepEqual(errors, [])
  console.log('PASS: normal login creates photo session, no extra password prompt on entry/reload, image compression, three uploads/limit, student results, teacher reward/rejection/filter, error retry, desktop/tablet/mobile overflow, no page errors')
} finally { await browser.close() }
