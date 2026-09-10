import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '../lib/supabase'
import { establishCheckinSession, checkinApi, checkinToken, sessionKey, sessionErrorKey } from '../lib/photoCheckins'

export interface Profile {
  id: string
  username: string
  password?: string
  role: 'student' | 'teacher'
  points: number
  badges?: string[]
  avatar_url: string | null
  class_name: string | null
  teacher_id: string | null
  is_admin: boolean
  created_at: string
}

export type TenantFeature = 'travel' | 'photo_checkin' | 'shop'
export const tenantFeatureKeys: TenantFeature[] = ['travel', 'photo_checkin', 'shop']
const USER_ID_KEY = 'pet_user_id'
const SESSION_EXPIRES_KEY = 'pet_session_expires_at'
const SESSION_DURATION_MS = 30 * 60 * 1000
const ACTIVITY_WRITE_INTERVAL_MS = 30 * 1000
const CHECKIN_RENEW_INTERVAL_MS = 5 * 60 * 1000
const checkinRenewedKey = (id: string) => `photo_checkin_renewed_at:${id}`

export async function hashPassword(password: string): Promise<string> {
  const encoder = new TextEncoder()
  const data = encoder.encode(password + 'pet-paradise-salt')
  const hashBuffer = await crypto.subtle.digest('SHA-256', data)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
}

export const useAuthStore = defineStore('auth', () => {
  const user = ref<Profile | null>(null)
  const initialized = ref(false)
  const loading = ref(false)
  const tenantFeatures = ref<Record<TenantFeature, boolean>>({ travel: false, photo_checkin: false, shop: false })
  const tenantFeaturesLoadedFor = ref<string | null>(null)

  const profile = computed(() => user.value)
  const isTeacher = computed(() => user.value?.role === 'teacher')
  const isStudent = computed(() => user.value?.role === 'student')
  const isAdmin = computed(() => user.value?.role === 'teacher' && user.value?.is_admin === true)
  let expiryTimer: ReturnType<typeof setTimeout> | null = null
  let lastActivityWrite = 0

  function clearExpiryTimer() {
    if (expiryTimer) clearTimeout(expiryTimer)
    expiryTimer = null
  }

  async function expireSession() {
    if (hasValidSession()) {
      scheduleExpiry(Number(localStorage.getItem(SESSION_EXPIRES_KEY)))
      return
    }
    await signOut()
    if (!window.location.hash.startsWith('#/login')) window.location.hash = '#/login?reason=expired'
  }

  function scheduleExpiry(expiresAt: number) {
    clearExpiryTimer()
    expiryTimer = setTimeout(() => { void expireSession() }, Math.max(0, expiresAt - Date.now()))
  }

  function saveSession(profileId: string, expiresAt = Date.now() + SESSION_DURATION_MS) {
    localStorage.setItem(USER_ID_KEY, profileId)
    localStorage.setItem(SESSION_EXPIRES_KEY, String(expiresAt))
    scheduleExpiry(expiresAt)
  }

  function hasValidSession() {
    const expiresAt = Number(localStorage.getItem(SESSION_EXPIRES_KEY))
    return Number.isFinite(expiresAt) && expiresAt > Date.now()
  }

  function syncSessionExpiry() {
    if (!user.value) return
    const expiresAt = Number(localStorage.getItem(SESSION_EXPIRES_KEY))
    if (Number.isFinite(expiresAt) && expiresAt > Date.now()) scheduleExpiry(expiresAt)
    else void expireSession()
  }

  function recordActivity() {
    if (!user.value) return
    if (!hasValidSession()) { void expireSession(); return }
    const now = Date.now()
    if (now - lastActivityWrite >= ACTIVITY_WRITE_INTERVAL_MS) {
      lastActivityWrite = now
      saveSession(user.value.id)
    }
    if (isAdmin.value || !checkinToken(user.value.id)) return
    const renewedKey = checkinRenewedKey(user.value.id)
    const renewedAt = Number(localStorage.getItem(renewedKey)) || 0
    if (now - renewedAt < CHECKIN_RENEW_INTERVAL_MS) return
    localStorage.setItem(renewedKey, String(now))
    const profileId = user.value.id
    void checkinApi(profileId, 'keepalive').catch(() => {
      if (!checkinToken(profileId)) void expireSession()
      else if (localStorage.getItem(renewedKey) === String(now)) localStorage.removeItem(renewedKey)
    })
  }

  function tenantId(profile = user.value) {
    if (!profile || profile.is_admin) return null
    return profile.role === 'teacher' ? profile.id : profile.teacher_id
  }

  async function fetchTenantFeatures(force = false) {
    const id = tenantId()
    if (!id) return { data: tenantFeatures.value, error: null }
    if (!force && tenantFeaturesLoadedFor.value === id) return { data: tenantFeatures.value, error: null }
    tenantFeatures.value = { travel: false, photo_checkin: false, shop: false }
    const { data, error } = await supabase.rpc('get_tenant_features', { p_tenant_id: id })
    if (!error && user.value && tenantId() === id) {
      const enabled = new Set((data || []).filter((row: any) => row.enabled).map((row: any) => row.feature_key))
      tenantFeatures.value = {
        travel: enabled.has('travel'),
        photo_checkin: enabled.has('photo_checkin'),
        shop: enabled.has('shop'),
      }
      tenantFeaturesLoadedFor.value = id
    }
    return { data: tenantFeatures.value, error }
  }

  function hasFeature(feature: TenantFeature) {
    return tenantFeaturesLoadedFor.value === tenantId() && tenantFeatures.value[feature] === true
  }

  async function init() {
    const savedUserId = localStorage.getItem(USER_ID_KEY)
    if (savedUserId && !hasValidSession()) {
      localStorage.removeItem(USER_ID_KEY)
      localStorage.removeItem(SESSION_EXPIRES_KEY)
    }
    if (savedUserId && hasValidSession()) {
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', savedUserId)
        .single()
      if (data) {
        user.value = data
        saveSession(data.id, Math.min(Number(localStorage.getItem(SESSION_EXPIRES_KEY)), Date.now() + SESSION_DURATION_MS))
        await fetchTenantFeatures()
      } else {
        localStorage.removeItem(USER_ID_KEY)
        localStorage.removeItem(SESSION_EXPIRES_KEY)
      }
    }
    initialized.value = true
  }

  async function fetchRegistrationClasses() {
    return await supabase
      .from('profiles')
      .select('id, username, class_name')
      .eq('role', 'teacher')
      .eq('is_admin', false)
      .order('class_name')
      .order('username')
  }

  async function fetchRegistrationEnabled() {
    const { data, error } = await supabase
      .from('settings')
      .select('value')
      .eq('key', 'registration_enabled')
      .maybeSingle()
    if (error) return { data: false, error }
    return { data: data?.value?.enabled !== false, error: null }
  }

  async function updateRegistrationEnabled(enabled: boolean) {
    if (!user.value || !isAdmin.value) return { error: new Error('仅管理员可修改注册设置') }
    const { data, error } = await supabase
      .from('settings')
      .upsert({ key: 'registration_enabled', value: { enabled }, updated_at: new Date().toISOString() }, { onConflict: 'key' })
      .select('value')
      .single()
    if (error) return { data: null, error }
    const savedEnabled = data?.value?.enabled === true
    if (savedEnabled !== enabled) return { data: null, error: new Error('注册设置未能正确保存，请重试') }
    return { data: savedEnabled, error: null }
  }

  async function signUp(username: string, password: string, teacherId: string) {
    loading.value = true
    try {
      const normalizedUsername = username.trim()
      const registration = await fetchRegistrationEnabled()
      if (registration.error) throw new Error('注册状态校验失败，请稍后重试')
      if (!registration.data) throw new Error('账号注册已关闭，请联系管理员')

      const { data: existing } = await supabase
        .from('profiles')
        .select('id')
        .eq('role', 'student')
        .eq('teacher_id', teacherId)
        .eq('username', normalizedUsername)
        .maybeSingle()

      if (existing) {
        throw new Error('该班级已经有同名学生')
      }

      const { data: teacher, error: classError } = await supabase
        .from('profiles')
        .select('id, class_name')
        .eq('id', teacherId)
        .eq('role', 'teacher')
        .eq('is_admin', false)
        .maybeSingle()
      if (classError) throw new Error('班级校验失败，请稍后重试')
      if (!teacher) {
        throw new Error('所选班级已不可用，请刷新后重新选择')
      }

      const hashedPwd = await hashPassword(password)
      const { data, error } = await supabase
        .from('profiles')
        .insert({
          username: normalizedUsername,
          password: hashedPwd,
          role: 'student',
          points: 0,
          teacher_id: teacher.id,
          class_name: teacher.class_name || '默认班级',
        })
        .select()
        .single()

      if (error) throw error

      user.value = data
      await fetchTenantFeatures(true)
      const checkinExpires = await establishCheckinSession(data.id, password)
      saveSession(data.id, checkinExpires ? Date.parse(checkinExpires) : undefined)
      return { data, error: null }
    } catch (error: any) {
      return { data: null, error }
    } finally {
      loading.value = false
    }
  }

  async function signIn(username: string, password: string, teacherId?: string) {
    loading.value = true
    try {
      const hashedPwd = await hashPassword(password)
      let query = supabase
        .from('profiles')
        .select('*')
        .eq('username', username.trim())
        .eq('password', hashedPwd)
      if (teacherId) {
        query = query.eq('role', 'student').eq('teacher_id', teacherId)
      }
      const { data, error } = await query.limit(2)

      if (error || !data || data.length === 0) {
        throw new Error('用户名或密码错误')
      }
      if (data.length > 1) {
        throw new Error('该名字存在于多个班级，请选择班级后登录')
      }

      user.value = data[0]
      await fetchTenantFeatures(true)
      const checkinExpires = !data[0].is_admin ? await establishCheckinSession(data[0].id, password) : null
      saveSession(data[0].id, checkinExpires ? Date.parse(checkinExpires) : undefined)
      return { data: data[0], error: null }
    } catch (error: any) {
      return { data: null, error }
    } finally {
      loading.value = false
    }
  }

  async function signOut() {
    clearExpiryTimer()
    if (user.value) {
      const key = sessionKey(user.value.id)
      const token = checkinToken(user.value.id)
      sessionStorage.removeItem(key)
      localStorage.removeItem(key)
      localStorage.removeItem(sessionErrorKey(user.value.id))
      localStorage.removeItem(checkinRenewedKey(user.value.id))
      if (token) void supabase.functions.invoke('photo-checkins', {
        body: { action: 'logout' }, headers: { 'x-checkin-token': token },
      }).catch(() => {})
    }
    user.value = null
    tenantFeatures.value = { travel: false, photo_checkin: false, shop: false }
    tenantFeaturesLoadedFor.value = null
    localStorage.removeItem(USER_ID_KEY)
    localStorage.removeItem(SESSION_EXPIRES_KEY)
  }

  async function refreshProfile() {
    if (!user.value) return
    const { data } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.value.id)
      .single()
    if (data) {
      user.value = data
    }
  }

  async function changeOwnPassword(currentPassword: string, newPassword: string) {
    if (!user.value || !isStudent.value) return { error: new Error('仅学生可在此修改密码') }
    if (newPassword.length < 4) return { error: new Error('新密码至少 4 位') }
    const [currentHash, newHash] = await Promise.all([hashPassword(currentPassword), hashPassword(newPassword)])
    const { error } = await supabase.rpc('change_student_password', {
      p_actor_id: user.value.id, p_current_password: currentHash, p_new_password: newHash,
    })
    if (error?.code === 'PGRST202') return { error: new Error('修改密码功能尚未启用，请先执行数据库迁移') }
    return { error: error ? new Error(error.message || '修改密码失败') : null }
  }

  async function updateClassName(className: string) {
    if (!user.value || !isTeacher.value) return { error: new Error('仅老师可修改班级名称') }
    const normalized = className.trim()
    if (!normalized) return { error: new Error('班级名称不能为空') }
    const { error } = await supabase
      .from('profiles')
      .update({ class_name: normalized })
      .eq('id', user.value.id)
      .eq('role', 'teacher')
    if (!error) user.value.class_name = normalized
    return { error }
  }

  async function createTeacher(username: string, password: string, className: string) {
    if (!user.value || !isAdmin.value) {
      return { data: null, error: new Error('仅管理员可添加老师账号') }
    }

    const normalizedUsername = username.trim()
    const normalizedClassName = className.trim()
    if (normalizedUsername.length < 2 || normalizedUsername.length > 20) {
      return { data: null, error: new Error('老师账号需要 2-20 个字符') }
    }
    if (password.length < 6) {
      return { data: null, error: new Error('初始密码至少 6 位') }
    }
    if (!normalizedClassName) {
      return { data: null, error: new Error('班级名称不能为空') }
    }

    const { data: existing } = await supabase
      .from('profiles')
      .select('id')
      .eq('username', normalizedUsername)
      .maybeSingle()
    if (existing) return { data: null, error: new Error('该账号已被使用') }

    const hashedPwd = await hashPassword(password)
    const { data, error } = await supabase
      .from('profiles')
      .insert({
        username: normalizedUsername,
        password: hashedPwd,
        role: 'teacher',
        points: 0,
        class_name: normalizedClassName,
        teacher_id: null,
        is_admin: false,
      })
      .select('id, username, role, class_name, created_at')
      .single()
    return { data, error }
  }

  async function fetchManagedTenantFeatures(teacherId: string) {
    if (!user.value || !isAdmin.value) return { data: [], error: new Error('仅管理员可查看班级功能') }
    return await supabase.rpc('get_tenant_features', { p_tenant_id: teacherId })
  }

  async function updateManagedTenantFeature(teacherId: string, feature: TenantFeature, enabled: boolean) {
    if (!user.value || !isAdmin.value) return { data: null, error: new Error('仅管理员可修改班级功能') }
    return await supabase.rpc('set_tenant_feature', {
      p_admin_id: user.value.id, p_tenant_id: teacherId, p_feature_key: feature, p_enabled: enabled,
    })
  }

  async function fetchTeachers() {
    if (!user.value || !isAdmin.value) return { data: [], error: new Error('仅管理员可查看老师账号') }
    const { data: teachers, error } = await supabase
      .from('profiles')
      .select('id, username, class_name, created_at')
      .eq('role', 'teacher')
      .eq('is_admin', false)
      .order('created_at', { ascending: false })
    if (error || !teachers) return { data: [], error }

    const teacherIds = teachers.map(teacher => teacher.id)
    const counts = new Map<string, number>()
    if (teacherIds.length > 0) {
      const { data: students } = await supabase
        .from('profiles')
        .select('teacher_id')
        .eq('role', 'student')
        .in('teacher_id', teacherIds)
      students?.forEach(student => {
        if (student.teacher_id) counts.set(student.teacher_id, (counts.get(student.teacher_id) || 0) + 1)
      })
    }
    return {
      data: teachers.map(teacher => ({ ...teacher, student_count: counts.get(teacher.id) || 0 })),
      error: null,
    }
  }

  async function deleteTeacher(teacherId: string) {
    if (!user.value || !isAdmin.value) return { error: new Error('仅管理员可删除老师账号') }
    const { count } = await supabase
      .from('profiles')
      .select('id', { count: 'exact', head: true })
      .eq('role', 'student')
      .eq('teacher_id', teacherId)
    if ((count || 0) > 0) return { error: new Error('该老师班级中仍有学生，不能删除') }
    const { error } = await supabase
      .from('profiles')
      .delete()
      .eq('id', teacherId)
      .eq('role', 'teacher')
      .eq('is_admin', false)
    return { error }
  }

  async function fetchTeacherStudents(teacherId: string) {
    if (!user.value || !isAdmin.value) return { data: [], error: new Error('仅管理员可查看学生') }
    const { data, error } = await supabase
      .from('profiles')
      .select('id, username, points, class_name, created_at')
      .eq('role', 'student')
      .eq('teacher_id', teacherId)
      .order('created_at', { ascending: false })
    return { data: data || [], error }
  }

  async function updateTeacherClass(teacherId: string, className: string) {
    if (!user.value || !isAdmin.value) return { error: new Error('仅管理员可修改班级') }
    const normalized = className.trim()
    if (!normalized) return { error: new Error('班级名称不能为空') }
    const { error } = await supabase
      .from('profiles')
      .update({ class_name: normalized })
      .eq('id', teacherId)
      .eq('role', 'teacher')
      .eq('is_admin', false)
    if (error) return { error }
    const { error: studentError } = await supabase
      .from('profiles')
      .update({ class_name: normalized })
      .eq('role', 'student')
      .eq('teacher_id', teacherId)
    return { error: studentError }
  }

  async function resetAccountPassword(accountId: string, password: string, role: 'teacher' | 'student') {
    if (!user.value || !isAdmin.value) return { error: new Error('仅管理员可重置密码') }
    if (password.length < 6) return { error: new Error('新密码至少 6 位') }
    const hashedPwd = await hashPassword(password)
    let query = supabase
      .from('profiles')
      .update({ password: hashedPwd })
      .eq('id', accountId)
      .eq('role', role)
    if (role === 'teacher') query = query.eq('is_admin', false)
    const { error } = await query
    return { error }
  }

  async function deleteManagedStudent(studentId: string, teacherId: string) {
    if (!user.value || !isAdmin.value) return { error: new Error('仅管理员可删除学生') }
    const { error } = await supabase
      .from('profiles')
      .delete()
      .eq('id', studentId)
      .eq('role', 'student')
      .eq('teacher_id', teacherId)
    return { error }
  }

  return { user, profile, initialized, loading, isTeacher, isStudent, isAdmin, tenantFeatures, fetchTenantFeatures, hasFeature, init, recordActivity, syncSessionExpiry, signUp, fetchRegistrationClasses, fetchRegistrationEnabled, updateRegistrationEnabled, signIn, signOut, refreshProfile, changeOwnPassword, updateClassName, createTeacher, fetchManagedTenantFeatures, updateManagedTenantFeature, fetchTeachers, deleteTeacher, fetchTeacherStudents, updateTeacherClass, resetAccountPassword, deleteManagedStudent }
})
