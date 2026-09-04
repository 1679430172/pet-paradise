import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '../lib/supabase'

export interface Profile {
  id: string
  username: string
  password?: string
  role: 'student' | 'teacher'
  points: number
  avatar_url: string | null
  class_name: string | null
  teacher_id: string | null
  is_admin: boolean
  created_at: string
}

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

  const profile = computed(() => user.value)
  const isTeacher = computed(() => user.value?.role === 'teacher')
  const isStudent = computed(() => user.value?.role === 'student')
  const isAdmin = computed(() => user.value?.role === 'teacher' && user.value?.is_admin === true)

  async function init() {
    const savedUserId = localStorage.getItem('pet_user_id')
    if (savedUserId) {
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', savedUserId)
        .single()
      if (data) {
        user.value = data
      } else {
        localStorage.removeItem('pet_user_id')
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
      localStorage.setItem('pet_user_id', data.id)
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
      localStorage.setItem('pet_user_id', data[0].id)
      return { data: data[0], error: null }
    } catch (error: any) {
      return { data: null, error }
    } finally {
      loading.value = false
    }
  }

  async function signOut() {
    user.value = null
    localStorage.removeItem('pet_user_id')
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

  return { user, profile, initialized, loading, isTeacher, isStudent, isAdmin, init, signUp, fetchRegistrationClasses, fetchRegistrationEnabled, updateRegistrationEnabled, signIn, signOut, refreshProfile, changeOwnPassword, updateClassName, createTeacher, fetchTeachers, deleteTeacher, fetchTeacherStudents, updateTeacherClass, resetAccountPassword, deleteManagedStudent }
})
