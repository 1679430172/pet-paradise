// Real Vue page + actual PostgreSQL RPCs in an isolated fixture. No production writes.
import assert from 'node:assert/strict'
import { pathToFileURL } from 'node:url'
import { mkdir } from 'node:fs/promises'
import path from 'node:path'
import { randomUUID } from 'node:crypto'
import { createFixture, seedDrop } from './travel-test-fixture.mjs'
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE ? pathToFileURL(process.env.PLAYWRIGHT_MODULE).href : 'playwright')
const { db, scalar, student, teacher, pet } = await createFixture({tickets:true})
const ticketTask=randomUUID()
await db.query("INSERT INTO tasks(id,name,points,travel_tickets,created_by) VALUES ($1,'阅读周任务',0,1,$2)",[ticketTask,teacher])
const output = process.env.ARTIFACT_DIR || 'artifacts/travel'
await mkdir(output,{recursive:true})
const browser = await chromium.launch({headless:true,channel:'chrome'})
const page = await browser.newPage({viewport:{width:1440,height:1050}})
page.setDefaultTimeout(15000)
const errors=[]
page.on('pageerror',e=>errors.push(e.message))
await page.addInitScript(id=>{if(!localStorage.getItem('pet_user_id')) localStorage.setItem('pet_user_id',id)},student)
let loseClaim=true, missingMigration=false
const rpcArgs={travel_state:['p_user_id'],start_pet_trip:['p_user_id','p_pet_id','p_destination_id','p_request_id'],claim_pet_trip:['p_user_id','p_trip_id'],redeem_travel_item:['p_user_id','p_item_id'],equip_pet_cosmetic:['p_actor_id','p_pet_id','p_category','p_item_id']}
rpcArgs.teacher_travel_ticket_usage=['p_actor_id','p_student_id','p_page']
rpcArgs.teacher_point_spending=['p_actor_id','p_student_id','p_page']
rpcArgs.teacher_student_ledger=['p_actor_id','p_student_id','p_page']
await page.route('**/rest/v1/**',async route=>{
  const req=route.request(),url=new URL(req.url()),resource=url.pathname.split('/rest/v1/')[1]
  const json=(body,status=200)=>route.fulfill({status,contentType:'application/json',body:JSON.stringify(body)})
  try {
    if(resource.startsWith('rpc/')) {
      const name=resource.slice(4), args=req.postDataJSON()
      if(missingMigration && name==='travel_state') return json({code:'PGRST202',message:'missing function'},404)
      assert.ok(rpcArgs[name],`Unexpected RPC ${name}`)
      const values=rpcArgs[name].map(k=>args[k])
      const result=await scalar(`SELECT ${name}(${values.map((_,i)=>'$'+(i+1)).join(',')})`,values)
      if(name==='claim_pet_trip' && loseClaim){loseClaim=false;return json({message:'response lost after commit'},503)}
      return json(result)
    }
    assert.ok(['profiles','pets','shop_items','user_items','shop_orders','pet_cosmetics','tasks','task_completions'].includes(resource),resource)
    if(resource==='tasks' && ['POST','PATCH'].includes(req.method())) {
      const data=req.postDataJSON(),keys=Object.keys(data)
      assert.ok(keys.every(k=>['name','description','points','travel_tickets','created_by','is_active'].includes(k)))
      const values=keys.map(k=>data[k])
      if(req.method()==='POST') {
        const result=await db.query(`INSERT INTO tasks(${keys.join(',')}) VALUES(${values.map((_,i)=>'$'+(i+1)).join(',')}) RETURNING *`,values)
        return json(result.rows[0])
      }
      values.push(url.searchParams.get('id').slice(3))
      await db.query(`UPDATE tasks SET ${keys.map((k,i)=>k+'=$'+(i+1)).join(',')} WHERE id=$${values.length}`,values)
      return json(null)
    }
    assert.equal(req.method(),'GET')
    const clauses=[],args=[]
    for(const column of ['id','owner_id','user_id','buyer_id','is_active','created_by','teacher_id','student_id']) {
      const value=url.searchParams.get(column)
      if(value?.startsWith('eq.')) {args.push(value.slice(3));clauses.push(`${column}=$${args.length}`)}
    }
    const {rows}=await db.query(`SELECT * FROM ${resource}${clauses.length?' WHERE '+clauses.join(' AND '):''}`,args)
    if(resource==='task_completions') for(const row of rows) row.task=(await db.query('SELECT name FROM tasks WHERE id=$1',[row.task_id])).rows[0]
    // The shop needs nested style selections, matching PostgREST's join shape.
    if(resource==='pet_cosmetics') for(const row of rows) {
      row.frame=row.frame_item_id?(await db.query('SELECT style_key FROM shop_items WHERE id=$1',[row.frame_item_id])).rows[0]:null
      row.background=row.background_item_id?(await db.query('SELECT style_key FROM shop_items WHERE id=$1',[row.background_item_id])).rows[0]:null
    }
    return json(req.headers().accept?.includes('vnd.pgrst.object')?rows[0]:rows)
  }catch(e){return json({message:e.message},400)}
})
const app=process.env.APP_URL||'http://127.0.0.1:5193'
await page.goto(app+'/#/travel')
await page.getByRole('button',{name:'暂无旅行券'}).first().waitFor()
assert.equal(await page.getByRole('button',{name:'暂无旅行券'}).first().isDisabled(),true)
await scalar('SELECT award_task_points($1,$2,$3,$4)',[teacher,student,ticketTask,randomUUID()])
await page.getByRole('button',{name:'刷新余额'}).click()
await page.getByRole('button',{name:'使用 1 张旅行券出发 →'}).first().waitFor()
for(const [width,height,name] of [[1440,1050,'desktop'],[768,1024,'tablet'],[390,844,'mobile'],[320,760,'small-mobile']]) {
  await page.setViewportSize({width,height})
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),`${name} horizontal overflow`)
  await page.screenshot({path:path.join(output,`${name}.png`),fullPage:true})
}
await page.getByRole('button',{name:'使用 1 张旅行券出发 →'}).first().click()
const confirmation=page.getByRole('dialog',{name:'出发去森林营地？'})
await confirmation.waitFor()
assert.equal(await scalar('SELECT tickets FROM travel_wallets WHERE user_id=$1',[student]),1,'opening confirmation does not consume tickets')
assert.equal(await scalar('SELECT count(*)::int FROM pet_trips WHERE user_id=$1',[student]),0)
await page.screenshot({path:path.join(output,'departure-confirm-mobile.png')})
await confirmation.getByRole('button',{name:'再想想'}).click()
await page.getByRole('button',{name:'使用 1 张旅行券出发 →'}).first().click()
await confirmation.waitFor()
await page.keyboard.press('Escape')
await confirmation.waitFor({state:'hidden'})
assert.equal(await scalar('SELECT tickets FROM travel_wallets WHERE user_id=$1',[student]),1,'cancel and Escape do not consume tickets')
await page.getByRole('button',{name:'使用 1 张旅行券出发 →'}).first().click()
await confirmation.getByRole('button',{name:'确认出发'}).click()
await page.getByRole('heading',{name:'小云正在森林营地'}).waitFor()
assert.equal(await scalar('SELECT tickets FROM travel_wallets WHERE user_id=$1',[student]),0)
await page.getByRole('heading',{name:'小云正在森林营地'}).waitFor()
assert.equal(await page.getByRole('button',{name:'正在收集沿途的风景'}).isDisabled(),true)
await page.reload()
await page.getByRole('heading',{name:'小云正在森林营地'}).waitFor()
// Changing the client wall clock cannot accelerate the trip.
await page.evaluate(()=>{Date.now=()=>new Date('2099-01-01').getTime()})
assert.equal(await page.getByRole('button',{name:'正在收集沿途的风景'}).isDisabled(),true)
await db.query("UPDATE pet_trips SET started_at=now()-interval '5 hours',returns_at=now()-interval '1 minute' WHERE user_id=$1",[student])
await page.reload()
await page.getByRole('button',{name:'打开旅行行李'}).waitFor()
await seedDrop(db,true)
await page.getByRole('button',{name:'打开旅行行李'}).click()
await page.getByRole('dialog').waitFor()
assert.equal(await scalar('SELECT stamps FROM travel_wallets WHERE user_id=$1',[student]),1,'lost-response retry does not double award')
await page.screenshot({path:path.join(output,'reward-mobile.png'),fullPage:true})
await page.keyboard.press('Escape')
await page.getByRole('heading',{name:'攒一张券，去看看远方'}).waitFor()
assert.equal(await page.getByRole('button',{name:'暂无旅行券'}).count(),3)
await page.getByRole('link',{name:'前往装扮屋 →'}).click()
const awardedCategory=await scalar('SELECT i.category FROM user_items u JOIN shop_items i ON i.id=u.item_id WHERE u.user_id=$1',[student])
if(awardedCategory==='background') await page.getByRole('button',{name:'背景',exact:true}).click()
await page.getByRole('button',{name:'立即装备'}).first().waitFor()
assert.equal(await page.getByRole('link',{name:'去旅行获取 →'}).count(),2)
await page.getByRole('button',{name:'立即装备'}).first().click()
await page.getByRole('button',{name:'已在使用 · 点击卸下'}).waitFor()
await db.query('UPDATE travel_wallets SET stamps=8 WHERE user_id=$1',[student])
await page.goto(app+'/#/travel')
await page.getByRole('button',{name:'兑换',exact:true}).first().waitFor()
await page.getByRole('button',{name:'兑换',exact:true}).first().click()
await page.getByRole('status').filter({hasText:'已兑换'}).waitFor()
assert.equal(await scalar('SELECT stamps FROM travel_wallets WHERE user_id=$1',[student]),0)
await page.setViewportSize({width:1440,height:1050})
await page.screenshot({path:path.join(output,'collection-desktop.png'),fullPage:true})
missingMigration=true
await page.reload()
await page.getByRole('alert').waitFor()
assert.equal(await page.getByRole('button',{name:'使用 1 张旅行券出发 →'}).count(),0,'missing migration fails closed')
missingMigration=false
await page.getByRole('button',{name:'重新加载'}).click()
await page.getByRole('heading',{name:'攒一张券，去看看远方'}).waitFor()
// Teacher can create a ticket-only task and edit it into a mixed reward.
await page.evaluate(id=>localStorage.setItem('pet_user_id',id),teacher)
await page.goto(app+'/?teacher-test=1#/teacher/tasks/new')
await page.getByRole('heading',{name:'新建任务'}).waitFor()
await page.getByPlaceholder('如：完成课堂练习').fill('旅行券测试任务')
await page.getByPlaceholder('如：10').fill('0')
await page.getByLabel('奖励旅行券').fill('2')
await page.getByRole('button',{name:'保存',exact:true}).click()
await page.getByText('旅行券测试任务',{exact:true}).waitFor()
const created=(await db.query("SELECT * FROM tasks WHERE name='旅行券测试任务'")).rows[0]
assert.equal(created.points,0);assert.equal(created.travel_tickets,2)
await page.goto(app+'/#/teacher/tasks/'+created.id+'/edit')
await page.getByRole('heading',{name:'编辑任务'}).waitFor()
await page.getByPlaceholder('如：10').fill('7')
await page.getByLabel('奖励旅行券').fill('1')
await page.getByRole('button',{name:'保存',exact:true}).click()
await page.getByText('7 积分 + 1 张旅行券',{exact:true}).waitFor()
await page.screenshot({path:path.join(output,'teacher-task-rewards.png'),fullPage:true})
await scalar('SELECT feed_pet($1,$2,$3,$4,$5)',[student,student,pet,'basic',randomUUID()])
const purchaseItem=await scalar("SELECT id FROM shop_items WHERE slug='frame-leaf'")
await scalar('SELECT purchase_shop_item($1,$2,$3)',[student,purchaseItem,randomUUID()])
await page.goto(app+'/#/teacher/students/'+student)
await page.getByRole('heading',{name:'收支记录'}).waitFor()
await page.getByText('−5 积分',{exact:true}).waitFor()
await page.getByText('−35 积分',{exact:true}).waitFor()
assert.equal(await page.locator('.history-section').count(),1)
await page.getByText('+1 张旅行券',{exact:true}).waitFor()
await page.getByText('−1 张旅行券',{exact:true}).waitFor()
await page.getByText('旅行出发 · 小云 · 森林营地',{exact:true}).waitFor()
assert.equal(await page.getByText('−1 张旅行券',{exact:true}).count(),1)
await page.screenshot({path:path.join(output,'teacher-ticket-usage.png'),fullPage:true})
await page.setViewportSize({width:390,height:844})
assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'student detail mobile overflow')
await page.screenshot({path:path.join(output,'teacher-ticket-usage-mobile.png'),fullPage:true})
assert.deepEqual(errors,[])
await browser.close();await db.close()
console.log('PASS: four viewport sizes, no-ticket gating, task-issued tickets, departure spending, reload persistence, client-clock tampering, claim retry, equipment, redemption, migration recovery, teacher ticket-only task creation and mixed-reward editing; '+output)
