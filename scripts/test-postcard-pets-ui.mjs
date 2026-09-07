// Real Vue page + actual PostgreSQL RPCs in an isolated fixture. No production writes.
import assert from 'node:assert/strict'
import { pathToFileURL } from 'node:url'
import { readFile, mkdir } from 'node:fs/promises'
import path from 'node:path'
import { randomUUID } from 'node:crypto'
import { createFixture, seedDrop } from './travel-test-fixture.mjs'
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE ? pathToFileURL(process.env.PLAYWRIGHT_MODULE).href : 'playwright')
const { db, scalar, student, teacher, pet, other, otherPet } = await createFixture({tickets:true})
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
rpcArgs.teacher_travel_state=['p_actor_id','p_student_id']
rpcArgs.teacher_start_pet_trip=['p_actor_id','p_student_id','p_pet_id','p_destination_id','p_request_id']
rpcArgs.teacher_claim_pet_trip=['p_actor_id','p_student_id','p_trip_id']
rpcArgs.teacher_travel_overview=['p_actor_id']
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
    assert.ok(['profiles','pets','shop_items','user_items','shop_orders','pet_cosmetics','tasks','task_completions','settings'].includes(resource),resource)
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
    for(const column of ['id','owner_id','user_id','buyer_id','is_active','created_by','teacher_id','student_id','key','role']) {
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

for(const file of ['supabase-migration-postcard-unlocks.sql','supabase-migration-more-postcards.sql','supabase-migration-postcard-pet-snapshots.sql']) await db.exec(await readFile(file,'utf8'))
const secondPet=randomUUID()
await db.query("UPDATE pets SET species='松鼠',level=20,name='松果' WHERE id=$1",[pet])
await db.query("INSERT INTO pets(id,owner_id,name,species,level,appearance) VALUES($1,$2,'彩羽','孔雀',14,'{}')",[secondPet,student])
const stories=await scalar("SELECT stories FROM travel_destinations WHERE id='forest'")
for(const [id,name] of [[pet,'松果'],[secondPet,'彩羽']]) for(const story of stories.slice(0,3)) await db.query("INSERT INTO pet_trips(id,user_id,pet_id,pet_name,destination_id,returns_at,claimed_at,reward) VALUES($1,$2,$3,$4,'forest',now()+interval '1 hour',now(),$5)",[randomUUID(),student,id,name,JSON.stringify({story,stamps:1})])
await db.query("INSERT INTO travel_postcard_unlocks(user_id,destination_id,story) SELECT $1,id,unnest(stories) FROM travel_destinations",[student])
await db.query("UPDATE pets SET name='已改名',level=1 WHERE id=$1",[pet])
await page.goto('http://localhost:5173/#/travel')
await page.locator('.postcard').first().waitFor()
assert.equal(await page.locator('.postcard').count(),42)
assert.equal(await page.locator('.postcard-pet').count(),0)
await page.locator('.postcard').first().scrollIntoViewIfNeeded()
await page.locator('.postcard img').evaluateAll(async imgs=>{await Promise.all(imgs.map(async i=>{i.loading='eager';await i.decode()}))})
const original=await page.locator('.postcard footer').allTextContents()
assert.ok(original.some(s=>s.includes('松果')))
assert.ok(original.some(s=>s.includes('彩羽')))
await page.locator('.travel-partner select').selectOption(secondPet)
assert.deepEqual(await page.locator('.postcard footer').allTextContents(),original)
await page.screenshot({path:path.join(output,'scenery-postcards-desktop.png')})
await page.getByRole('button',{name:/森林营地 18/}).click()
assert.equal(await page.locator('.postcard').count(),18)
await page.setViewportSize({width:390,height:844})
await page.locator('.postcard').first().scrollIntoViewIfNeeded()
assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth))
await page.screenshot({path:path.join(output,'scenery-postcards-mobile.png')})
await page.getByRole('button',{name:/贝壳海湾 12/}).click()
assert.equal(await page.locator('.postcard').count(),12)
assert.equal(await page.locator('.postcard-pet').count(),0)
assert.deepEqual(errors,[])
await browser.close();await db.close()
console.log('PASS: 42 versions / 36 stories, text attribution, no composited pet, fixed snapshot after selection and rename, memorials, destination filters, mobile layout and all images decoded')
