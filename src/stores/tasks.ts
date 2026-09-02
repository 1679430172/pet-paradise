import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from './auth'
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

  async function awardPoints(studentId: string, taskId: string) {
    const authStore = useAuthStore()
    if (!authStore.user) return { error: new Error('未登录') }

    const task = tasks.value.find(t => t.id === taskId)
    if (!task) return { error: new Error('任务不存在') }

    loading.value = true
    try {
      const { data: ownedStudent } = await supabase
        .from('profiles')
        .select('id')
        .eq('id', studentId)
        .eq('teacher_id', authStore.user.id)
        .maybeSingle()
      if (!ownedStudent || task.created_by !== authStore.user.id) {
        throw new Error('只能给自己班级的学生发放本班任务积分')
      }

      // 插入完成记录
      const { error: insertErr } = await supabase
        .from('task_completions')
        .insert({
          task_id: taskId,
          student_id: studentId,
          awarded_by: authStore.user.id,
          points: task.points,
        })
      if (insertErr) throw insertErr

      // 给学生加积分
      const { data: student } = await supabase
        .from('profiles')
        .select('points')
        .eq('id', studentId)
        .single()

      if (student) {
        const { error: updateErr } = await supabase
          .from('profiles')
          .update({ points: student.points + task.points })
          .eq('id', studentId)
        if (updateErr) throw updateErr
      }

      return { error: null, points: task.points }
    } catch (error: any) {
      return { error }
    } finally {
      loading.value = false
    }
  }

  async function awardPointsToStudents(
    studentIds: string[],
    taskId: string,
    onProgress?: (completed: number, total: number) => void,
  ) {
    const authStore = useAuthStore()
    if (!authStore.user) return { error: new Error('未登录'), awardedCount: 0 }

    const uniqueStudentIds = [...new Set(studentIds)]
    if (uniqueStudentIds.length === 0) {
      return { error: new Error('请至少选择一名学生'), awardedCount: 0 }
    }

    const task = tasks.value.find(t => t.id === taskId)
    if (!task) return { error: new Error('任务不存在'), awardedCount: 0 }
    if (task.created_by !== authStore.user.id) {
      return { error: new Error('只能发放自己创建的班级任务积分'), awardedCount: 0 }
    }

    loading.value = true
    const awardedStudentIds: string[] = []
    const teacherId = authStore.user.id
    const taskPoints = task.points
    try {
      const { data: ownedStudents, error: studentsError } = await supabase
        .from('profiles')
        .select('id, points')
        .in('id', uniqueStudentIds)
        .eq('role', 'student')
        .eq('teacher_id', authStore.user.id)
      if (studentsError) throw studentsError
      if (!ownedStudents || ownedStudents.length !== uniqueStudentIds.length) {
        throw new Error('所选学生中包含不属于当前班级的学生')
      }

      const { failed } = await runBatch(ownedStudents, async (student) => {
        const { error: insertErr } = await supabase
          .from('task_completions')
          .insert({
            task_id: taskId,
            student_id: student.id,
            awarded_by: teacherId,
            points: taskPoints,
          })
        if (insertErr) throw insertErr

        const { data: updatedStudent, error: updateErr } = await supabase
          .from('profiles')
          .update({ points: student.points + taskPoints })
          .eq('id', student.id)
          .eq('teacher_id', teacherId)
          .select('id')
          .single()
        if (updateErr) throw updateErr
        if (!updatedStudent) throw new Error('学生已不存在或已转班')
        awardedStudentIds.push(student.id)
      }, onProgress)
      if (failed.length > 0) throw failed[0]!.error

      return { error: null, points: task.points, awardedCount: awardedStudentIds.length, awardedStudentIds }
    } catch (error: any) {
      return { error, awardedCount: awardedStudentIds.length, awardedStudentIds }
    } finally {
      loading.value = false
    }
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

  return { tasks, completions, loading, fetchTasks, fetchAllTasks, createTask, updateTask, deleteTask, awardPoints, awardPointsToStudents, fetchCompletions }
})
