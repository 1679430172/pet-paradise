import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { hashPassword } from './auth'
import { usePointsStore } from './points'
import { ACTIONS, LEVEL_THRESHOLDS, MAX_LEVEL } from '../lib/constants'
import type { Profile } from './auth'
import { useAuthStore } from './auth'

export interface TeacherPet {
  id: string
  owner_id?: string
  name: string
  species: string
  level: number
  xp?: number
  hunger?: number
  happiness?: number
  cleanliness?: number
  appearance?: any
  created_at?: string
}

export interface StudentWithPet extends Profile {
  pets: TeacherPet[]
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

  function teacherId(): string | null {
    return useAuthStore().user?.id || null
  }

  async function fetchStudents(search?: string) {
    const currentTeacherId = teacherId()
    if (!currentTeacherId) return
    loading.value = true
    let query = supabase
      .from('profiles')
      .select('*')
      .eq('role', 'student')
      .eq('teacher_id', currentTeacherId)
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
    const currentTeacherId = teacherId()
    if (!currentTeacherId) return
    loading.value = true
    let query = supabase
      .from('profiles')
      .select('*')
      .eq('role', 'student')
      .eq('teacher_id', currentTeacherId)
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
        .order('created_at', { ascending: true })
      petsData = data || []
    }
    const petMap = new Map<string, TeacherPet[]>()
    petsData.forEach(p => {
      const arr = petMap.get(p.owner_id) || []
      arr.push(p)
      petMap.set(p.owner_id, arr)
    })
    studentsWithPets.value = studentsData.map(s => ({
      ...s,
      pets: petMap.get(s.id) || [],
    }))
    totalStudents.value = studentsData.length
    loading.value = false
  }

  function calculateLevel(xp: number): number {
    for (let i = LEVEL_THRESHOLDS.length - 1; i >= 0; i--) {
      if (xp >= LEVEL_THRESHOLDS[i]) return Math.min(MAX_LEVEL, i + 1)
    }
    return 1
  }

  async function performActionForStudent(studentId: string, petId: string, action: 'basic' | 'nice' | 'luxury') {
    const currentTeacherId = teacherId()
    if (!currentTeacherId) return { error: new Error('未登录') }
    const pointsStore = usePointsStore()
    await pointsStore.fetchActionCosts()
    const cost = pointsStore.actionCosts[action]

    const { data: student } = await supabase
      .from('profiles')
      .select('points')
      .eq('id', studentId)
      .eq('teacher_id', currentTeacherId)
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
    const newStatVal = Math.min(100, (pet.hunger || 0) + config.statGain)
    const newXp = (pet.xp || 0) + config.xp
    const newLevel = calculateLevel(newXp)
    const now = new Date().toISOString()

    const { error: petErr } = await supabase
      .from('pets')
      .update({
        hunger: newStatVal,
        last_fed_at: now,
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
      const targetPet = target.pets?.find(p => p.id === petId)
      if (targetPet) {
        targetPet.hunger = newStatVal
        targetPet.xp = newXp
        targetPet.level = newLevel
      }
    }

    return { error: null, cost, newLevel, leveledUp: newLevel > (pet.level || 1) }
  }

  async function fetchStudentDetail(id: string) {
    const currentTeacherId = teacherId()
    if (!currentTeacherId) return { profile: null, pets: [], completions: [] }
    const { data: profile } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', id)
      .eq('teacher_id', currentTeacherId)
      .single()

    if (!profile) return { profile: null, pets: [], completions: [] }

    const { data: pets } = await supabase
      .from('pets')
      .select('*')
      .eq('owner_id', id)
      .order('created_at', { ascending: true })

    const { data: completions } = await supabase
      .from('task_completions')
      .select('*, task:tasks(name)')
      .eq('student_id', id)
      .order('created_at', { ascending: false })
      .limit(20)

    return { profile, pets: pets || [], completions }
  }

  async function fetchLeaderboard() {
    const currentTeacherId = teacherId()
    if (!currentTeacherId) return
    loading.value = true
    const { data: studentsData } = await supabase
      .from('profiles')
      .select('id, username, points')
      .eq('role', 'student')
      .eq('teacher_id', currentTeacherId)
      .order('points', { ascending: false })
      .limit(50)

    if (studentsData) {
      const entries: LeaderboardEntry[] = []
      for (const s of studentsData) {
        const { data: pets } = await supabase
          .from('pets')
          .select('name, level')
          .eq('owner_id', s.id)
          .order('level', { ascending: false })
          .limit(1)
        const top = pets && pets[0]
        entries.push({
          id: s.id,
          username: s.username,
          points: s.points,
          pet_level: top?.level || 0,
          pet_name: top?.name || '未创建',
        })
      }
      leaderboard.value = entries
    }
    loading.value = false
  }

  async function createStudent(username: string, password: string) {
    const authStore = useAuthStore()
    if (!authStore.user) return { data: null, error: new Error('未登录') }
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
        .insert({
          username,
          password: hashedPwd,
          role: 'student',
          points: 0,
          teacher_id: authStore.user.id,
          class_name: authStore.user.class_name || '默认班级',
        })
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
    const currentTeacherId = teacherId()
    if (!currentTeacherId) return { data: null, error: new Error('未登录') }
    loading.value = true
    try {
      const { data: ownedStudent } = await supabase
        .from('profiles')
        .select('id')
        .eq('id', studentId)
        .eq('teacher_id', currentTeacherId)
        .maybeSingle()
      if (!ownedStudent) throw new Error('该学生不属于当前老师')
      const { data: existing } = await supabase
        .from('pets')
        .select('id, level')
        .eq('owner_id', studentId)
      const hasUnmaxed = (existing || []).some((p: any) => (p.level || 1) < MAX_LEVEL)
      if (hasUnmaxed) {
        throw new Error('该学生已有未满级（Lv.20）的宠物，暂不能领养新宠物')
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
    const currentTeacherId = teacherId()
    if (!currentTeacherId) return { error: new Error('未登录') }
    const { error } = await supabase
      .from('profiles')
      .delete()
      .eq('id', id)
      .eq('role', 'student')
      .eq('teacher_id', currentTeacherId)
    if (!error) {
      students.value = students.value.filter(s => s.id !== id)
      totalStudents.value = students.value.length
    }
    return { error }
  }

  async function fetchStats() {
    const currentTeacherId = teacherId()
    if (!currentTeacherId) return
    const { data: studentsData } = await supabase
      .from('profiles')
      .select('id')
      .eq('role', 'student')
      .eq('teacher_id', currentTeacherId)
    totalStudents.value = studentsData?.length || 0

    const { data: completionsData } = await supabase
      .from('task_completions')
      .select('points')
      .eq('awarded_by', currentTeacherId)
    totalPointsGiven.value = completionsData?.reduce((sum, c) => sum + c.points, 0) || 0
  }

  return { students, studentsWithPets, leaderboard, loading, totalStudents, totalPointsGiven, fetchStudents, fetchStudentsWithPets, performActionForStudent, fetchStudentDetail, fetchLeaderboard, fetchStats, createStudent, adoptPetForStudent, deleteStudent }
})
