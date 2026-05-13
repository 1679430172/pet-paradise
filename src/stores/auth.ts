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
  created_at: string
}

async function hashPassword(password: string): Promise<string> {
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

  async function signUp(username: string, password: string) {
    loading.value = true
    try {
      const { data: existing } = await supabase
        .from('profiles')
        .select('id')
        .eq('username', username)
        .single()

      if (existing) {
        throw new Error('用户名已被注册')
      }

      const hashedPwd = await hashPassword(password)
      const { data, error } = await supabase
        .from('profiles')
        .insert({ username, password: hashedPwd, role: 'student', points: 0 })
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

  async function signIn(username: string, password: string) {
    loading.value = true
    try {
      const hashedPwd = await hashPassword(password)
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('username', username)
        .eq('password', hashedPwd)
        .single()

      if (error || !data) {
        throw new Error('用户名或密码错误')
      }

      user.value = data
      localStorage.setItem('pet_user_id', data.id)
      return { data, error: null }
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

  return { user, profile, initialized, loading, isTeacher, isStudent, init, signUp, signIn, signOut, refreshProfile }
})
