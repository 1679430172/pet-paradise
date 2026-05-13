import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { hashPassword } from './auth'
import { usePointsStore } from './points'
import { ACTIONS, LEVEL_THRESHOLDS } from '../lib/constants'
import type { Profile } from './auth'

export interface StudentWithPet extends Profile {
  pet?: {
    id?: string
    name: string
    species: string
    level: number
    xp?: number
    hunger?: number
    happiness?: number
    cleanliness?: number
    appearance?: any
  } | null
}

export interface LeaderboardEntry {
  id: string
  username: string
  points: number
  pet_level: number
  pet_name: string
}

export const useTeacherStore = defineStore('teacher', () => {
  const students = ref<StudentWithPet[]>([])
  const studentsWithPets = ref<StudentWithPet[]>([])
  const leaderboard = ref<LeaderboardEntry[]>([])
  const loading = ref(false)
  const totalStudents = ref(0)
  const totalPointsGiven = ref(0)

  async function fetchStudents(search?: string) {
    loading.value = true
    let query = supabase
      .from('profiles')
      .select('*')
      .eq('role', 'student')
      .order('created_at', { ascending: false })

    if (search) {
      query = query.ilike('username', `%${search}%`)
    }

    const { data } = await query
    if (data) {
      students.value = data
      totalStudents.value = data.length
    }
    loading.value = false
  }

  async function fetchStudentsWithPets(search?: string) {
    loading.value = true
    let query = supabase
      .from('profiles')
      .select('*')
      .eq('role', 'student')
      .order('created_at', { ascending: false })
    if (search) {
      query = query.ilike('username', `%${search}%`)
    }
    const { data: studentsData } = await query
    if (!studentsData) {
      studentsWithPets.value = []
      loading.value = false
      return
    }
    const ids = studentsData.map(s => s.id)
    let petsData: any[] = []
    if (ids.length > 0) {
      const { data } = await supabase
        .from('pets')
        .select('*')
        .in('owner_id', ids)
      petsData = data || []
    }
    const petMap = new Map<string, any>()
    petsData.forEach(p => petMap.set(p.owner_id, p))
    studentsWithPets.value = studentsData.map(s => ({
      ...s,
      pet: petMap.get(s.id) || null,
    }))
    totalStudents.value = studentsData.length
    loading.value = false
  }

  function calculateLevel(xp: number): number {
    for (let i = LEVEL_THRESHOLDS.length - 1; i >= 0; i--) {
      if (xp >= LEVEL_THRESHOLDS[i]) return i + 1
    }
    return 1
  }

  async function performActionForStudent(studentId: string, petId: string, action: 'feed' | 'play' | 'clean') {
    const pointsStore = usePointsStore()
    await pointsStore.fetchActionCosts()
    const cost = pointsStore.actionCosts[action]

    const { data: student } = await supabase
      .from('profiles')
      .select('points')
      .eq('id', studentId)
      .single()
    if (!student) return { error: new Error('学生不存在') }
    if (student.points < cost) {
      return { error: new Error(`学生积分不足，需要 ${cost} 积分`) }
    }

    const { data: pet } = await supabase
      .from('pets')
      .select('*')
      .eq('id', petId)
      .single()
    if (!pet) return { error: new Error('宠物不存在') }

    const config = ACTIONS[action]
    const statKey = config.statKey
    const newStatVal = Math.min(100, (pet[statKey] || 0) + config.statGain)
    const newXp = (pet.xp || 0) + config.xp
    const newLevel = calculateLevel(newXp)
    const now = new Date().toISOString()
    const lastAtKey = action === 'feed' ? 'last_fed_at' : action === 'play' ? 'last_played_at' : 'last_cleaned_at'

    const { error: petErr } = await supabase
      .from('pets')
      .update({
        [statKey]: newStatVal,
        [lastAtKey]: now,
        xp: newXp,
        level: newLevel,
      })
      .eq('id', petId)
    if (petErr) return { error: petErr }

    const { error: ptErr } = await supabase
      .from('profiles')
      .update({ points: student.points - cost })
      .eq('id', studentId)
    if (ptErr) return { error: ptErr }

    // 同步更新本地状态
    const target = studentsWithPets.value.find(s => s.id === studentId)
    if (target) {
      target.points = student.points - cost
      if (target.pet) {
        ;(target.pet as any)[statKey] = newStatVal
        target.pet.xp = newXp
        target.pet.level = newLevel
      }
    }

    return { error: null, cost, newLevel, leveledUp: newLevel > (pet.level || 1) }
  }

  async function fetchStudentDetail(id: string) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', id)
      .single()

    const { data: pet } = await supabase
      .from('pets')
      .select('*')
      .eq('owner_id', id)
      .single()

    const { data: completions } = await supabase
      .from('task_completions')
      .select('*, task:tasks(name)')
      .eq('student_id', id)
      .order('created_at', { ascending: false })
      .limit(20)

    return { profile, pet, completions }
  }

  async function fetchLeaderboard() {
    loading.value = true
    const { data: studentsData } = await supabase
      .from('profiles')
      .select('id, username, points')
      .eq('role', 'student')
      .order('points', { ascending: false })
      .limit(50)

    if (studentsData) {
      const entries: LeaderboardEntry[] = []
      for (const s of studentsData) {
        const { data: pet } = await supabase
          .from('pets')
          .select('name, level')
          .eq('owner_id', s.id)
          .single()
        entries.push({
          id: s.id,
          username: s.username,
          points: s.points,
          pet_level: pet?.level || 0,
          pet_name: pet?.name || '未创建',
        })
      }
      leaderboard.value = entries
    }
    loading.value = false
  }

  async function createStudent(username: string, password: string) {
    loading.value = true
    try {
      const { data: existing } = await supabase
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle()
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
      if (data) {
        students.value = [data, ...students.value]
        totalStudents.value = students.value.length
      }
      return { data, error: null }
    } catch (error: any) {
      return { data: null, error }
    } finally {
      loading.value = false
    }
  }

  async function adoptPetForStudent(studentId: string, name: string, species: string, color: string) {
    loading.value = true
    try {
      const { data: existing } = await supabase
        .from('pets')
        .select('id')
        .eq('owner_id', studentId)
        .maybeSingle()
      if (existing) {
        throw new Error('该学生已有宠物')
      }
      const { data, error } = await supabase
        .from('pets')
        .insert({
          owner_id: studentId,
          name,
          species,
          appearance: { color },
          level: 1,
          xp: 0,
          hunger: 100,
          happiness: 100,
          cleanliness: 100,
          badges: ['first_pet'],
        })
        .select()
        .single()
      if (error) throw error
      return { data, error: null }
    } catch (error: any) {
      return { data: null, error }
    } finally {
      loading.value = false
    }
  }

  async function deleteStudent(id: string) {
    const { error } = await supabase
      .from('profiles')
      .delete()
      .eq('id', id)
      .eq('role', 'student')
    if (!error) {
      students.value = students.value.filter(s => s.id !== id)
      totalStudents.value = students.value.length
    }
    return { error }
  }

  async function fetchStats() {
    const { data: studentsData } = await supabase
      .from('profiles')
      .select('id')
      .eq('role', 'student')
    totalStudents.value = studentsData?.length || 0

    const { data: completionsData } = await supabase
      .from('task_completions')
      .select('points')
    totalPointsGiven.value = completionsData?.reduce((sum, c) => sum + c.points, 0) || 0
  }

  return { students, studentsWithPets, leaderboard, loading, totalStudents, totalPointsGiven, fetchStudents, fetchStudentsWithPets, performActionForStudent, fetchStudentDetail, fetchLeaderboard, fetchStats, createStudent, adoptPetForStudent, deleteStudent }
})
