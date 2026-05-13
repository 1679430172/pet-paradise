import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import type { Profile } from './auth'

export interface StudentWithPet extends Profile {
  pet?: {
    name: string
    species: string
    level: number
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

  return { students, leaderboard, loading, totalStudents, totalPointsGiven, fetchStudents, fetchStudentDetail, fetchLeaderboard, fetchStats, deleteStudent }
})
