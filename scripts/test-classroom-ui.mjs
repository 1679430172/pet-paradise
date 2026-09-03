// Actual Vue application + isolated PostgreSQL RPCs through a test-only REST adapter.
// Set PLAYWRIGHT_MODULE, PGLITE_MODULE, APP_URL and ARTIFACT_DIR as needed.
import assert from 'node:assert/strict'
import { readFile, mkdir } from 'node:fs/promises'
import { pathToFileURL } from 'node:url'
import { randomUUID } from 'node:crypto'
import path from 'node:path'
const load = name => process.env[name] ? pathToFileURL(process.env[name]).href : name === 'PGLITE_MODULE' ? '@electric-sql/pglite' : 'playwright'
const { PGlite } = await import(load('PGLITE_MODULE'))
const { chromium } = await import(load('PLAYWRIGHT_MODULE'))
const db = new PGlite()
const schema = await readFile(new URL('../supabase-schema.sql', import.meta.url),'utf8')
await db.exec('CREATE ROLE anon; CREATE ROLE authenticated;')
await db.exec(schema.slice(0,schema.indexOf('-- RLS 策略')).replace(/-- =+\s*$/,''))
await db.exec(await readFile(new URL('../supabase-migration-classroom.sql',import.meta.url),'utf8'))
await db.exec(await readFile(new URL('../supabase-migration-revoke-awards.sql',import.meta.url),'utf8'))
const teacher = randomUUID(), task = randomUUID(), ids = []
await db.query(`INSERT INTO profiles(id,username,password,role,class_name) VALUES($1,'林老师','test','teacher','向日葵一班')`,[teacher])
const names = ['陈小雨','林子墨','王星然','赵可欣','周一诺','许安安','苏沐阳','李思齐','何小满','吴乐乐','宋知远','郑米粒']
const species = ['紫电龙','星焰狐','云朵猫','碧海龟','小狗','小兔子']
const colors = ['#e2c5ed','#f9d3ae','#c9dcec','#d3e6c7','#f6e3ac','#f4c7d3']
for (let i=0;i<names.length;i++) {
  const id = randomUUID(); ids.push(id)
  await db.query(`INSERT INTO profiles(id,username,password,role,points,teacher_id) VALUES($1,$2,'test','student',50,$3)`,[id,names[i],teacher])
  if (i<11) await db.query(`INSERT INTO pets(owner_id,name,species,appearance,level,xp) VALUES($1,$2,$3,$4,1,14)`,[id,`小${['紫','焰','云','海','旺','月'][i%6]}`,species[i%6],{color:colors[i%6]}])
}
await db.query(`INSERT INTO pets(owner_id,name,species,appearance,level,xp) VALUES($1,'小月','小兔子',$2,1,0)`,[ids[0],{color:'#f4c7d3'}])
await db.query(`INSERT INTO tasks(id,name,points,created_by) VALUES($1,'认真听讲',10,$2)`,[task,teacher])
const browser = await chromium.launch({headless:true, channel:process.env.BROWSER_CHANNEL || 'chrome'})
const page = await browser.newPage({viewport:{width:1440,height:1080}})
const errors = []
page.on('pageerror',error=>errors.push(error.message))
await page.addInitScript(id=>localStorage.setItem('pet_user_id',id),teacher)
await page.route('https://fonts.googleapis.com/**', route => route.fulfill({contentType:'text/css',body:''}))
let dropRevokeResponse = true
let dropFeedResponse = true, failStudent = null, missingRanking = false
await page.route('**/rest/v1/**',async route=>{
  const url = new URL(route.request().url())
  const resource = url.pathname.split('/rest/v1/')[1]
  const json = async (body,status=200) => route.fulfill({status,contentType:'application/json',body:JSON.stringify(body)})
  try {
    if (resource.startsWith('rpc/')) {
      const name=resource.slice(4), a=route.request().postDataJSON()
      if(name==='weekly_leaderboard' && missingRanking) return json({code:'PGRST202',message:'missing'},404)
      if(name==='award_task_points' && a.p_student_id===failStudent) return json({message:'测试：该学生发放失败'},400)
      const args = name==='feed_pet' ? [a.p_actor_id,a.p_student_id,a.p_pet_id,a.p_action,a.p_request_id]
        : name==='award_task_points' ? [a.p_actor_id,a.p_student_id,a.p_task_id,a.p_request_id]
        : name==='weekly_leaderboard' || name==='teacher_award_total' ? [a.p_teacher_id]
        : name==='revoke_task_award' ? [a.p_actor_id,a.p_completion_id,a.p_reason] : null
      assert.ok(args,`unexpected RPC ${name}`)
      const {rows}=await db.query(`SELECT ${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) AS result`,args)
      if(name==='feed_pet' && dropFeedResponse) { dropFeedResponse=false; return json({message:'simulated lost response'},503) }
      if(name==='revoke_task_award' && dropRevokeResponse) { dropRevokeResponse=false; return json({message:'simulated lost response'},503) }
      return json(rows[0].result)
    }
    assert.equal(route.request().method(),'GET','all writes must use RPC')
    assert.ok(['profiles','pets','settings','tasks','task_completions'].includes(resource))
    const conditions=[],args=[]
    for(const [key,value] of url.searchParams) {
      if(['select','order','limit','offset'].includes(key)) continue
      assert.match(key,/^[a-z_]+$/)
      if(value.startsWith('eq.')) { args.push(value.slice(3)); conditions.push(`${key}=$${args.length}`) }
      else if(value.startsWith('in.(')) {
        const list=value.slice(4,-1).split(','); const marks=list.map(v=>{args.push(v);return '$'+args.length})
        conditions.push(`${key} IN (${marks.join(',')})`)
      } else assert.fail(`unexpected filter ${value}`)
    }
    let sql=`SELECT * FROM ${resource}`+(conditions.length?' WHERE '+conditions.join(' AND '):'')
    const order=url.searchParams.get('order')
    if(order) { const [column,direction]=order.split(',')[0].split('.');assert.match(column,/^[a-z_]+$/);sql+=` ORDER BY ${column} ${direction==='desc'?'DESC':'ASC'}` }
    const {rows}=await db.query(sql,args)
    if(resource==='task_completions') {
      const start=Number(url.searchParams.get('offset')||0), limit=Number(url.searchParams.get('limit')||rows.length)
      const records=[]
      for(const row of rows.slice(start,start+limit)) {
        const student=(await db.query('SELECT username FROM profiles WHERE id=$1',[row.student_id])).rows[0]
        const task=(await db.query('SELECT name FROM tasks WHERE id=$1',[row.task_id])).rows[0]
        records.push({...row,student,task})
      }
      return route.fulfill({status:200,contentType:'application/json',headers:{'access-control-expose-headers':'content-range','content-range':`${start}-${start+records.length-1}/${rows.length}`},body:JSON.stringify(records)})
    }
    return json(route.request().headers().accept?.includes('vnd.pgrst.object')?rows[0]:rows)
  } catch(error) { if (!error.message.includes('学生当前余额')) errors.push(error.message); return json({message:error.message},400) }
})
const root=process.env.APP_URL || 'http://127.0.0.1:5193/'
const out=process.env.ARTIFACT_DIR || path.resolve('classroom-verification.local')
await mkdir(out,{recursive:true})
try {
  const response=await page.goto(root+'#/teacher/pets',{waitUntil:'domcontentloaded'})
  assert.equal(response.status(),200,'real Vite HTTP response')
  await page.locator('.pet-card').nth(11).waitFor()
  const normalBackground=await page.locator('.pet-card').filter({has:page.getByRole('heading',{name:'陈小雨',exact:true})}).evaluate(el=>getComputedStyle(el).backgroundImage)
  assert.match(normalBackground,/linear-gradient/)
  await page.screenshot({path:path.join(out,'pets-soft-normal.png')})
  await page.locator('.adopt-btn').first().click()
  await page.locator('.dialog .species-card').first().click()
  await page.getByRole('button',{name:'选择晴空蓝',exact:true}).click()
  assert.equal(await page.getByRole('button',{name:'选择晴空蓝',exact:true}).getAttribute('aria-pressed'),'true')
  const swatch=await page.getByRole('button',{name:'选择晴空蓝',exact:true}).locator('.theme-swatch').evaluate(el=>getComputedStyle(el).backgroundImage)
  const preview=await page.locator('.pet-preview').evaluate(el=>getComputedStyle(el).backgroundImage)
  assert.equal(preview,swatch,'color choice and adoption preview use exactly the same gradient')
  await page.locator('.pet-preview').scrollIntoViewIfNeeded()
  await page.screenshot({path:path.join(out,'pet-colors-preview.png')})
  await page.getByRole('button',{name:'取消',exact:true}).click()

  await page.getByRole('button',{name:'课堂大屏',exact:true}).click()
  await page.locator('.classroom-mode').waitFor()
  assert.equal(await page.locator('.pet-card').filter({has:page.getByRole('heading',{name:'陈小雨',exact:true})}).evaluate(el=>getComputedStyle(el).backgroundImage),normalBackground,'normal and classroom colors match')
  assert.equal(await page.locator('.teacher-nav').count(),0)
  const width=await page.locator('.classroom-mode').evaluate(el=>el.getBoundingClientRect().width)
  assert.equal(width,1440,'large screen fills viewport')
  const toolbarBefore = await page.locator('.pets-toolbar').boundingBox()
  await page.locator('.pets-content').evaluate(el => { el.scrollTop = 420 })
  const toolbarAfter = await page.locator('.pets-toolbar').boundingBox()
  const contentBox = await page.locator('.pets-content').boundingBox()
  assert.deepEqual(toolbarAfter,toolbarBefore,'toolbar stays outside the scrolling list')
  assert.ok(contentBox.y >= toolbarAfter.y + toolbarAfter.height,'list viewport begins below the toolbar')
  assert.ok(await page.locator('.pets-content').evaluate(el=>el.scrollTop)>0,'only the student region scrolls')
  await page.screenshot({path:path.join(out,'classroom-scrolled.png')})
  await page.locator('.pets-content').evaluate(el=>el.scrollTo(0,0))
  await page.getByPlaceholder('搜索学生...').fill('陈小雨')
  assert.equal(await page.locator('.pet-card').count(),1)
  await page.getByPlaceholder('搜索学生...').fill('')
  const selectableCard=page.locator('.pet-card').filter({has:page.getByRole('heading',{name:'陈小雨',exact:true})})
  await selectableCard.click({position:{x:70,y:100}})
  assert.equal(await page.getByRole('checkbox',{name:'选择 陈小雨',exact:true}).isChecked(),true,'card surface selects student')
  await page.getByRole('checkbox',{name:'选择 陈小雨',exact:true}).focus()
  await page.keyboard.press('Space')
  assert.equal(await page.getByRole('checkbox',{name:'选择 陈小雨',exact:true}).isChecked(),false,'keyboard toggles selection')
  await page.getByRole('checkbox',{name:'选择 陈小雨',exact:true}).check()
  await page.getByRole('checkbox',{name:'选择 林子墨',exact:true}).check()
  await page.getByLabel('选择奖励任务').selectOption(task)
  await page.locator('.pets-content').evaluate(el=>el.scrollTo(0,el.scrollHeight))
  await page.screenshot({path:path.join(out,'classroom-soft-selected.png')})
  await page.getByRole('button',{name:'发放奖励',exact:true}).click()
  await page.getByRole('status').filter({hasText:'已为 2 位同学'}).waitFor()
  await page.locator('.pets-content').evaluate(el=>el.scrollTo(0,0))
  await page.screenshot({path:path.join(out,'classroom-desktop.png')})
  const card=page.locator('.pet-card').filter({has:page.getByRole('heading',{name:'陈小雨',exact:true})})
  await card.getByRole('button',{name:'下一只宠物',exact:true}).click()
  assert.equal(await page.getByRole('checkbox',{name:'选择 陈小雨',exact:true}).isChecked(),false,'switching pets does not select the card')
  await card.getByRole('button',{name:'上一只宠物',exact:true}).click()
  await card.getByTitle('普通粮 -5',{exact:true}).click()
  await page.locator('.upgrade-student-name').waitFor()
  assert.equal(await page.getByRole('checkbox',{name:'选择 陈小雨',exact:true}).isChecked(),false,'feeding does not select the card')
  assert.match(await page.locator('.upgrade-student-name').textContent(),/陈小雨/)
  assert.equal((await db.query('SELECT points FROM profiles WHERE id=$1',[ids[0]])).rows[0].points,55,'lost response retry charges once')
  assert.equal((await db.query('SELECT count(*)::int AS n FROM feeding_events')).rows[0].n,1)
  await page.screenshot({path:path.join(out,'classroom-upgrade.png')})
  await page.getByRole('checkbox',{name:'选择 王星然',exact:true}).check()
  await page.getByRole('checkbox',{name:'选择 郑米粒',exact:true}).check()
  failStudent=ids[2]
  await page.getByRole('button',{name:'发放奖励',exact:true}).click()
  await page.locator('.classroom-failures').waitFor()
  assert.match(await page.locator('.classroom-notice').textContent(),/已奖励 1 人，1 人未完成/)
  assert.equal(await page.getByRole('checkbox',{name:'选择 王星然',exact:true}).isChecked(),true)
  assert.equal(await page.getByRole('checkbox',{name:'选择 郑米粒',exact:true}).isChecked(),false)
  await page.getByRole('button',{name:'全屏显示',exact:true}).click()
  await page.getByRole('button',{name:'退出全屏',exact:true}).waitFor()
  await page.getByRole('button',{name:'退出全屏',exact:true}).click()
  await page.locator('.upgrade-overlay').waitFor({state:'hidden'})
  await page.setViewportSize({width:390,height:844})
  await page.locator('.pets-content').evaluate(el=>el.scrollTo(0,0))
  assert.equal(await page.locator('.classroom-mode').evaluate(el=>el.scrollWidth<=el.clientWidth),true,'no mobile horizontal overflow')
  await page.screenshot({path:path.join(out,'classroom-mobile.png')})
  await page.getByRole('button',{name:'返回普通视图',exact:true}).click()
  await page.locator('.teacher-nav').waitFor()
  await page.setViewportSize({width:1440,height:1080})
  await page.goto(root+'#/teacher/stats',{waitUntil:'domcontentloaded'})
  await page.locator('.rank-item').nth(11).waitFor()
  assert.equal(await page.locator('.rank-points').first().textContent(),'10 本周获得')
  await page.screenshot({path:path.join(out,'weekly-ranking.png')})
  missingRanking=true
  await page.getByRole('button',{name:'刷新',exact:true}).click()
  await page.getByRole('alert').waitFor()
  assert.match(await page.getByRole('alert').textContent(),/数据库迁移/)
  missingRanking=false
  await page.goto(root+'#/teacher',{waitUntil:'domcontentloaded'})
  await page.locator('.completion-item').nth(2).waitFor()
  assert.match(await page.locator('.pagination').textContent(),/共 3 条/)
  const awardRow=page.locator('.completion-item').filter({hasText:'陈小雨'})
  await awardRow.getByRole('button',{name:'撤销',exact:true}).click()
  await page.getByLabel('撤销原因',{exact:true}).fill('选错学生')
  await page.getByRole('button',{name:'确认撤销',exact:true}).click()
  await awardRow.getByText('已撤销',{exact:true}).waitFor()
  assert.equal((await db.query('SELECT points FROM profiles WHERE id=$1',[ids[0]])).rows[0].points,45,'revocation lost response retries without double deduction')
  assert.equal(await awardRow.getByRole('button',{name:'撤销',exact:true}).count(),0)
  const recordHeights=await page.locator('.completion-item').evaluateAll(items=>items.map(el=>el.getBoundingClientRect().height))
  assert.equal(new Set(recordHeights).size,1,'revoked and active records have equal heights')
  await awardRow.locator('.revoked-detail').click()
  await page.getByRole('heading',{name:'撤销详情',exact:true}).waitFor()
  await page.getByRole('button',{name:'关闭',exact:true}).click()
  await page.screenshot({path:path.join(out,'award-revoked.png')})
  await db.query('UPDATE profiles SET points=0 WHERE id=$1',[ids[1]])
  await page.locator('.completion-item').filter({hasText:'林子墨'}).getByRole('button',{name:'撤销',exact:true}).click()
  await page.getByLabel('撤销原因',{exact:true}).fill('重复奖励')
  await page.getByRole('button',{name:'确认撤销',exact:true}).click()
  await page.getByRole('alert').filter({hasText:'余额'}).waitFor()
  await page.screenshot({path:path.join(out,'award-revoke-insufficient.png')})
  await page.getByRole('button',{name:'取消',exact:true}).click()
  assert.deepEqual(errors,[])
  console.log('PASS: Vue + PostgreSQL integration, search, multi-select award, partial failure, petless award, feed retry idempotency, named upgrade, fullscreen toggle, mobile layout, navigation restore, weekly rank, missing migration error. Screenshots: '+out)
} catch (error) { console.error('UI errors:',errors, 'URL:',page.url(), 'Body:',(await page.locator('body').innerText()).slice(0,1800)); throw error } finally { await browser.close(); await db.close() }
