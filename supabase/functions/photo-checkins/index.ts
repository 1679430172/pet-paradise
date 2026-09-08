import { createClient } from 'npm:@supabase/supabase-js@2.105.4'

const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false, autoRefreshToken: false },
})
const bucket = db.storage.from('photo-checkins')
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info, x-checkin-token, x-cleanup-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
class HttpError extends Error { constructor(message: string, public status = 400) { super(message) } }
const hash = async (s: string) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s))), b => b.toString(16).padStart(2, '0')).join('')
function checked<T>(r: { data: T; error: { message: string } | null }): T {
  if (r.error) throw new HttpError(r.error.message)
  return r.data
}
function id(value: unknown): string {
  if (typeof value !== 'string' || !uuid.test(value)) throw new HttpError('无效的记录编号')
  return value
}
function note(value: unknown): string {
  if (typeof value !== 'string' || value.length > 200) throw new HttpError('说明或反馈不能超过 200 字')
  return value.trim()
}
// 限制真实请求体，而不只信任 Content-Length。
async function body(req: Request) {
  const reader = req.body?.getReader()
  if (!reader) throw new HttpError('缺少请求内容')
  const chunks: Uint8Array[] = []; let size = 0
  while (true) {
    const { value, done } = await reader.read()
    if (done) break
    size += value.length
    if (size > 300000) { await reader.cancel(); throw new HttpError('照片过大，请压缩后重试', 413) }
    chunks.push(value)
  }
  const bytes = new Uint8Array(size); let offset = 0
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length }
  return JSON.parse(new TextDecoder().decode(bytes))
}

Deno.serve(async req => {
  const respond = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
    status, headers: { ...cors, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  })
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors })
  if (req.method !== 'POST') return respond({ error: '仅支持 POST' }, 405)
  try {
    const input = await body(req)
    if (input.action === 'cleanup') {
      const secret = Deno.env.get('PHOTO_CHECKIN_CLEANUP_SECRET')
      if (!secret || req.headers.get('x-cleanup-secret') !== secret) throw new HttpError('无权执行清理', 403)
      let deleted = 0
      // 每次最多 500 张；删除失败保留路径及容量占用，下次重试。
      for (let batch = 0; batch < 5; batch++) {
        const rows = checked(await db.rpc('claim_expired_photo_checkins')) || []
        if (!rows.length) break
        checked(await bucket.remove(rows.map((r: { object_path: string }) => r.object_path)))
        checked(await db.from('photo_checkins').update({ photo_deleted_at: new Date().toISOString() }).in('id', rows.map((r: { id: string }) => r.id)))
        deleted += rows.length
      }
      checked(await db.from('photo_checkin_sessions').delete().lt('expires_at', new Date().toISOString()))
      checked(await db.from('photo_checkin_login_limits').delete().lt('window_start', new Date(Date.now() - 86400000).toISOString()))
      return respond({ deleted })
    }
    if (input.action === 'login') {
      const profileId = id(input.profileId)
      if (typeof input.password !== 'string' || input.password.length > 200) throw new HttpError('密码错误', 401)
      const allowed = checked(await db.rpc('photo_checkin_login_attempt', { p_profile: profileId }))
      if (!allowed) throw new HttpError('验证次数过多，请 15 分钟后重试', 429)
      const profile = checked(await db.from('profiles').select('id,password,role,is_admin').eq('id', profileId).maybeSingle())
      if (!profile || profile.is_admin || !['student', 'teacher'].includes(profile.role) || await hash(input.password + 'pet-paradise-salt') !== profile.password) throw new HttpError('密码错误', 401)
      const token = crypto.randomUUID() + crypto.randomUUID()
      const expires = new Date(Date.now() + 12 * 3600000).toISOString()
      checked(await db.from('photo_checkin_sessions').insert({ token_hash: await hash(token), profile_id: profile.id, password_hash: profile.password, expires_at: expires }))
      return respond({ token, expires })
    }
    const token = req.headers.get('x-checkin-token') || ''
    if (token.length !== 72) throw new HttpError('请验证当前账号密码', 401)
    const session = checked(await db.from('photo_checkin_sessions').select('*').eq('token_hash', await hash(token)).gt('expires_at', new Date().toISOString()).maybeSingle())
    if (!session) throw new HttpError('验证已过期，请重新输入密码', 401)
    const actor = checked(await db.from('profiles').select('id,password,role,is_admin,teacher_id').eq('id', session.profile_id).maybeSingle())
    if (!actor || actor.password !== session.password_hash || actor.is_admin) throw new HttpError('账号已变化，请重新验证', 401)
    if (input.action === 'logout') {
      checked(await db.from('photo_checkin_sessions').delete().eq('token_hash', session.token_hash))
      return respond({ ok: true })
    }
    if (input.action === 'upload') {
      if (actor.role !== 'student') throw new HttpError('仅学生可以上传', 403)
      const requestId = id(input.id); const description = note(input.description)
      if (typeof input.image !== 'string' || input.image.length > 273068) throw new HttpError('照片大小不能超过 200 KB')
      const bytes = Uint8Array.from(atob(input.image), c => c.charCodeAt(0))
      if (bytes.length > 204800 || bytes.length < 4 || bytes[0] !== 255 || bytes[1] !== 216 || bytes[2] !== 255 || bytes[bytes.length - 2] !== 255 || bytes[bytes.length - 1] !== 217) throw new HttpError('请上传有效的 JPEG 照片')
      const row = checked(await db.rpc('reserve_photo_checkin', { p_actor: actor.id, p_id: requestId, p_bytes: bytes.length, p_description: description }))
      if (row.submitted_at) return respond({ ok: true })
      if (row.status !== 'uploading' || Date.parse(row.expires_at) <= Date.now()) throw new HttpError('上传已过期，请重新选择照片')
      const uploaded = await bucket.upload(row.object_path, bytes, { contentType: 'image/jpeg', upsert: false })
      // 同一请求重试时对象可能已经上传；不覆盖已有照片。
      if (uploaded.error && !['409', '400'].includes(String((uploaded.error as { statusCode?: string }).statusCode))) throw new HttpError('照片上传失败，请重试')
      if (uploaded.error) {
        const existing = await bucket.info(row.object_path)
        if (existing.error || Number(existing.data?.size) !== bytes.length) throw new HttpError('照片上传失败，请重试')
      }
      const finished = await db.rpc('finish_photo_checkin', { p_actor: actor.id, p_id: requestId })
      if (finished.error) {
        // 清理器可能在上传过程中使旧预留过期；补删刚上传的文件，避免遗留对象。
        // 不删除已完成提交的照片，响应丢失或并发重试仍可安全恢复。
        const current = checked(await db.from('photo_checkins').select('status,submitted_at,expires_at').eq('id', requestId).single())
        if (current && !current.submitted_at && (current.status === 'failed' || Date.parse(current.expires_at) <= Date.now())) {
          const removed = await bucket.remove([row.object_path])
          if (!removed.error) checked(await db.from('photo_checkins').update({ status: 'failed', photo_deleted_at: new Date().toISOString() }).eq('id', requestId).is('submitted_at', null))
          else checked(await db.from('photo_checkins').update({ photo_deleted_at: null }).eq('id', requestId).is('submitted_at', null))
        }
        throw new HttpError(finished.error.message)
      }
      return respond({ ok: true })
    }
    if (input.action === 'review') {
      if (actor.role !== 'teacher') throw new HttpError('仅教师可以审核', 403)
      if (!Number.isInteger(input.points)) throw new HttpError('积分必须是整数')
      checked(await db.rpc('review_photo_checkin', { p_actor: actor.id, p_id: id(input.id), p_points: input.points, p_feedback: note(input.feedback) }))
      return respond({ ok: true })
    }
    if (input.action === 'list') {
      const page = Math.max(1, Math.min(100000, Math.floor(Number(input.page) || 1)))
      let query = db.from('photo_checkins').select('id,student_id,student_name,class_name,description,status,points,feedback,created_at,submitted_at,reviewed_at,expires_at,photo_deleted_at,object_path', { count: 'exact' }).not('submitted_at', 'is', null)
      query = actor.role === 'teacher' ? query.eq('teacher_id', actor.id) : query.eq('student_id', actor.id)
      if (input.status) {
        if (!['pending', 'awarded', 'rejected', 'expired'].includes(input.status)) throw new HttpError('无效状态')
        if (input.status === 'pending') query = query.eq('status', 'pending').gt('expires_at', new Date().toISOString())
        else if (input.status === 'expired') query = query.or(`status.eq.expired,and(status.eq.pending,expires_at.lte.${new Date().toISOString()})`)
        else query = query.eq('status', input.status)
      }
      if (input.studentId) query = query.eq('student_id', id(input.studentId))
      if (input.day) {
        if (!/^\d{4}-\d{2}-\d{2}$/.test(input.day)) throw new HttpError('日期格式错误')
        query = query.eq('submission_day', input.day)
      }
      const result = await query.order('created_at', { ascending: false }).order('id', { ascending: false }).range((page - 1) * 12, page * 12 - 1)
      const rows = checked(result) || []
      const entries = await Promise.all(rows.map(async row => {
        const { object_path, ...entry } = row
        if (entry.status === 'pending' && Date.parse(entry.expires_at) <= Date.now()) entry.status = 'expired'
        const expired = Date.parse(entry.expires_at) <= Date.now()
        const signed = !entry.photo_deleted_at && !expired ? await bucket.createSignedUrl(object_path, 600) : null
        return { ...entry, image_url: signed?.data?.signedUrl || null, image_error: !!signed?.error }
      }))
      const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Shanghai', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date())
      const daily = actor.role === 'student' ? await db.from('photo_checkins').select('id', { count: 'exact', head: true }).eq('student_id', actor.id).eq('submission_day', today) : null
      if (daily?.error) throw new HttpError(daily.error.message)
      const students = actor.role === 'teacher' ? checked(await db.from('profiles').select('id,username,class_name').eq('teacher_id', actor.id).eq('role', 'student').order('username')) : []
      const urgent = actor.role === 'teacher' ? await db.from('photo_checkins').select('id', { count: 'exact', head: true }).eq('teacher_id', actor.id).eq('status', 'pending').gt('expires_at', new Date().toISOString()).lt('expires_at', new Date(Date.now() + 2 * 86400000).toISOString()) : null
      if (urgent?.error) throw new HttpError(urgent.error.message)
      const revokedIds = entries.length ? checked(await db.from('task_completions').select('id,revoked_at').in('id', entries.map(r => r.id)).not('revoked_at', 'is', null)) || [] : []
      return respond({ entries: entries.map(r => ({ ...r, revoked: revokedIds.some(c => c.id === r.id) })), total: result.count || 0, todayCount: daily?.count || 0, students, urgentCount: urgent?.count || 0 })
    }
    throw new HttpError('不支持的操作')
  } catch (error) {
    return respond({ error: error instanceof HttpError ? error.message : '服务暂时不可用，请稍后重试' }, error instanceof HttpError ? error.status : 500)
  }
})
