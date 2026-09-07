// Real Vue page + actual PostgreSQL RPCs in an isolated fixture. No production writes.
import assert from 'node:assert/strict'
import { pathToFileURL } from 'node:url'
import { mkdir, readFile } from 'node:fs/promises'
import path from 'node:path'
import { randomUUID } from 'node:crypto'
import { createFixture, seedDrop } from './travel-test-fixture.mjs'
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE ? pathToFileURL(process.env.PLAYWRIGHT_MODULE).href : 'playwright')
const { db, scalar, student, teacher, pet, other, otherPet } = await createFixture({tickets:true})
await db.exec(await readFile(new URL('../supabase-migration-travel-care.sql',import.meta.url),'utf8'))
await db.query('INSERT INTO travel_wallets(user_id,tickets) VALUES($1,1)',[student])
await scalar('SELECT start_pet_trip($1,$2,$3,$4)',[student,pet,'forest',randomUUID()])
await db.query("INSERT INTO pets(owner_id,name,species) VALUES($1,'留在家的伙伴','云朵猫')",[student])
const ticketTask=randomUUID()
await db.query("INSERT INTO tasks(id,name,points,travel_tickets,created_by) VALUES ($1,'阅读周任务',0,1,$2)",[ticketTask,teacher])
const output = process.env.ARTIFACT_DIR || 'artifacts/travel'
await mkdir(output,{recursive:true})
const browser = await chromium.launch({headless:true,channel:'chrome'})
const page = await browser.newPage({viewport:{width:1440,height:1050}})
page.setDefaultTimeout(15000)
const errors=[]
page.on('pageerror',e=>errors.push(e.message))
await page.addInitScript(id=>{if(!localStorage.getItem('pet_user_id')) localStorage.setItem('pet_user_id',id)},teacher)
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
const app=process.env.APP_URL||'http://127.0.0.1:5193'
await page.goto(app+'/#/teacher/pets')
await page.locator('.travel-scene').waitFor()
assert.equal(await page.locator('.travelling-card .btn-action').count(),0)
await page.getByRole('button',{name:'批量投喂',exact:true}).click()
assert.equal(await page.locator('.batch-pet-option').filter({hasText:'小云'}).count(),0)
await page.reload()
await page.locator('.travel-scene').waitFor()
for(const width of [1440,768,390,320]) {
 await page.setViewportSize({width,height:1000})
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth))
 await page.screenshot({path:path.join(output,`travel-care-${width}.png`),fullPage:true})
}
assert.deepEqual(errors,[])
await browser.close();await db.close()
console.log('PASS: travel scene, feeding hidden, batch exclusion and responsive widths')
