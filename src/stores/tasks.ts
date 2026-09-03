import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from './auth'
import { classroomRpc } from '../lib/classroomApi'
import { runBatch } from '../lib/runBatch'

export interface Task {
  id: string
  name: string
  description: string | null
  points: number
  is_active: boolean
  created_by: string
  created_at: string
}

export interface TaskCompletion {
  revoked_at?: string | null
  revoked_by?: string | null
  revoke_reason?: string | null
  id: string
  task_id: string
  student_id: string
  awarded_by: string
  points: number
  created_at: string
  task?: Task
  student?: { username: string }
}

export const useTasksStore = defineStore('tasks', () => {
  const tasks = ref<Task[]>([])
  const completions = ref<TaskCompletion[]>([])
  const loading = ref(false)

  async function fetchTasks() {
    const authStore = useAuthStore()
    if (!authStore.user) return
    const { data } = await supabase
      .from('tasks')
      .select('*')
      .eq('is_active', true)
      .eq('created_by', authStore.isTeacher ? authStore.user.id : authStore.user.teacher_id)
      .order('created_at', { ascending: false })
    if (data) tasks.value = data
  }

  async function fetchAllTasks() {
    const authStore = useAuthStore()
    if (!authStore.user) return
    const { data } = await supabase
      .from('tasks')
      .select('*')
      .eq('created_by', authStore.user.id)
      .order('created_at', { ascending: false })
    if (data) tasks.value = data
  }

  async function createTask(name: string, description: string, points: number) {
    const authStore = useAuthStore()
    if (!authStore.user) return { error: new Error('未登录') }
    loading.value = true
    try {
      const { data, error } = await supabase
        .from('tasks')
        .insert({ name, description, points, created_by: authStore.user.id })
        .select()
        .single()
      if (error) throw error
      tasks.value.unshift(data)
      return { data, error: null }
    } catch (error: any) {
      return { data: null, error }
    } finally {
      loading.value = false
    }
  }

  async function updateTask(id: string, updates: Partial<Pick<Task, 'name' | 'description' | 'points' | 'is_active'>>) {
    loading.value = true
    try {
      const { error } = await supabase
        .from('tasks')
        .update(updates)
        .eq('id', id)
        .eq('created_by', useAuthStore().user?.id)
      if (error) throw error
      const idx = tasks.value.findIndex(t => t.id === id)
      if (idx >= 0) Object.assign(tasks.value[idx], updates)
      return { error: null }
    } catch (error: any) {
      return { error }
    } finally {
      loading.value = false
    }
  }

  async function deleteTask(id: string) {
    loading.value = true
    try {
      const { error } = await supabase
        .from('tasks')
        .update({ is_active: false })
        .eq('id', id)
        .eq('created_by', useAuthStore().user?.id)
      if (error) throw error
      tasks.value = tasks.value.filter(t => t.id !== id)
      return { error: null }
    } catch (error: any) {
      return { error }
    } finally {
      loading.value = false
    }
  }

  async function awardOne(studentId: string, taskId: string) {
    const actor = useAuthStore().user
    if (!actor) throw new Error('未登录')
    return classroomRpc<{ points: number; balance: number }>('award_task_points', {
      p_actor_id: actor.id, p_student_id: studentId, p_task_id: taskId, p_request_id: crypto.randomUUID(),
    })
  }

  async function awardPoints(studentId: string, taskId: string) {
    loading.value = true
    try {
      return { error: null, ...await awardOne(studentId, taskId) }
    } catch (error: any) {
      return { error }
    } finally {
      loading.value = false
    }
  }

  async function awardPointsToStudents(
    studentIds: string[], taskId: string,
    onProgress?: (completed: number, total: number) => void,
  ) {
    const ids = [...new Set(studentIds)]
    const awardedStudentIds: string[] = []
    const failures: { studentId: string; message: string }[] = []
    const balances: Record<string, number> = {}
    let points = 0
    loading.value = true
    try {
      if (!ids.length) throw new Error('请至少选择一名学生')
      await runBatch(ids, async (id) => {
        try {
          const result = await awardOne(id, taskId)
          points = result.points
          balances[id] = result.balance
          awardedStudentIds.push(id)
        } catch (error) {
          failures.push({ studentId: id, message: error instanceof Error ? error.message : '发放失败' })
        }
      }, onProgress)
      return { error: failures.length ? new Error(failures[0]!.message) : null,
        points, awardedCount: awardedStudentIds.length, awardedStudentIds, balances, failures }
    } catch (error: any) {
      return { error, points, awardedCount: awardedStudentIds.length, awardedStudentIds, balances, failures }
    } finally {
      loading.value = false
    }
  }

  async function revokeAward(completionId: string, reason: string) {
    const actor = useAuthStore().user
    if (!actor) throw new Error('未登录')
    const result = await classroomRpc<{ balance: number; completion: TaskCompletion; alreadyRevoked: boolean }>(
      'revoke_task_award', { p_actor_id: actor.id, p_completion_id: completionId, p_reason: reason },
    )
    const existing = completions.value.find(c => c.id === completionId)
    if (existing) Object.assign(existing, result.completion)
    return result
  }

  async function fetchCompletions(studentId?: string) {
    let query = supabase
      .from('task_completions')
      .select('*, task:tasks(name, points)')
      .order('created_at', { ascending: false })
      .limit(50)

    if (studentId) {
      query = query.eq('student_id', studentId)
    }

    const { data } = await query
    if (data) completions.value = data
  }

  return { revokeAward, tasks, completions, loading, fetchTasks, fetchAllTasks, createTask, updateTask, deleteTask, awardPoints, awardPointsToStudents, fetchCompletions }
})
