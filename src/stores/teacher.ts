import { acceptHMRUpdate, defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { hashPassword } from './auth'
import { feedPet, classroomRpc } from '../lib/classroomApi'
import { MAX_LEVEL, STAT_DECAY_PER_HOUR } from '../lib/constants'
import type { Profile } from './auth'
import { useAuthStore } from './auth'
import type { CosmeticSelection } from '../lib/cosmetics'
import type { ShopItem } from './shop'

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
  last_fed_at?: string | null
  appearance?: any
  created_at?: string
  cosmetics?: CosmeticSelection
}

export interface StudentWithPet extends Profile {
  pets: TeacherPet[]
}

export interface LeaderboardEntry {
  rank: number | null
  id: string
  username: string
  points: number
  pet_level: number
  pet_name: string
  pet_species?: string
  pet_id?: string
  cosmetics?: CosmeticSelection
}

export const useTeacherStore = defineStore('teacher', () => {
  const students = ref<StudentWithPet[]>([])
  const studentsWithPets = ref<StudentWithPet[]>([])
  const leaderboard = ref<LeaderboardEntry[]>([])
  const loading = ref(false)
  const totalStudents = ref(0)
  const totalPointsGiven = ref(0)
  const cosmeticItems = ref<ShopItem[]>([])
  const cosmeticOwnedIds = ref<string[]>([])

  function teacherId(): string | null {
    return useAuthStore().user?.id || null
  }

  function hungerWithDecay(pet: TeacherPet): number {
    const hunger = pet.hunger ?? 0
    const referenceAt = pet.last_fed_at || pet.created_at
    if (!referenceAt) return hunger
    const elapsed = Date.now() - new Date(referenceAt).getTime()
    const hours = Math.max(0, Math.floor(elapsed / (60 * 60 * 1000)))
    const decay = Math.floor(hours * STAT_DECAY_PER_HOUR)
    return Math.max(0, hunger - decay)
  }

  function applyHungerDecay<T extends TeacherPet>(pet: T): T {
    return { ...pet, hunger: hungerWithDecay(pet) }
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

  async function fetchStudentsWithPets(search?: string, background = false) {
    const currentTeacherId = teacherId()
    if (!currentTeacherId) return
    if (!background) loading.value = true
    try {
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
      if (!studentsData) return
      const ids = studentsData.map(s => s.id)
      let petsData: any[] = []
      if (ids.length > 0) {
        const { data, error } = await supabase
          .from('pets')
          .select('*')
          .in('owner_id', ids)
          .order('created_at', { ascending: true })
        if (error) return
        petsData = (data || []).map(applyHungerDecay)
        const petIds = petsData.map(p => p.id)
        if (petIds.length) {
          const { data: cosmeticData } = await supabase
            .from('pet_cosmetics')
            .select('pet_id,frame:shop_items!pet_cosmetics_frame_item_id_fkey(style_key),background:shop_items!pet_cosmetics_background_item_id_fkey(style_key)')
            .in('pet_id', petIds)
          const cosmeticMap = new Map((cosmeticData || []).map((row: any) => [row.pet_id, {
            frame: row.frame?.style_key || null, background: row.background?.style_key || null,
          }]))
          petsData = petsData.map(pet => ({ ...pet, cosmetics: cosmeticMap.get(pet.id) }))
        }
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
    } finally {
      if (!background) loading.value = false
    }
  }

  const feedingStudents = new Set<string>()
  async function performActionForStudent(studentId: string, petId: string, action: 'basic' | 'nice' | 'luxury') {
    const actorId = teacherId()
    if (!actorId) return { error: new Error('未登录') }
    if (feedingStudents.has(studentId)) return { error: new Error('正在投喂该学生的宠物，请稍候') }
    feedingStudents.add(studentId)
    try {
      const result = await feedPet(actorId, studentId, petId, action)
      for (const list of [students.value, studentsWithPets.value]) {
        const student = list.find(s => s.id === studentId)
        if (!student) continue
        student.points = result.points
        const pet = student.pets?.find(p => p.id === petId)
        if (pet) Object.assign(pet, result.pet)
      }
      return { error: null, cost: result.cost, newLevel: result.pet.level, leveledUp: result.leveledUp }
    } catch (error) {
      return { error: error instanceof Error ? error : new Error('投喂失败') }
    } finally {
      feedingStudents.delete(studentId)
    }
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

    return { profile, pets: (pets || []).map(applyHungerDecay), completions }
  }

  const leaderboardError = ref('')
  const leaderboardLoading = ref(false)
  const leaderboardWeek = ref({ start: '', end: '' })
  async function fetchLeaderboard() {
    const currentTeacherId = teacherId()
    if (!currentTeacherId || leaderboardLoading.value) return
    leaderboardLoading.value = true
    leaderboardError.value = ''
    try {
      const result = await classroomRpc<{ entries: LeaderboardEntry[]; weekStart: string; weekEnd: string }>(
        'weekly_leaderboard', { p_teacher_id: currentTeacherId },
      )
      const studentIds = result.entries.map(entry => entry.id)
      const { data: rankingPets, error: petError } = studentIds.length
        ? await supabase.from('pets').select('id,owner_id,name,species,level,created_at').in('owner_id', studentIds)
        : { data: [], error: null }
      if (petError) throw petError
      // Match the weekly ranking's representative pet: highest level, then oldest adoption.
      const sortedPets = [...(rankingPets || [])].sort((a, b) =>
        b.level - a.level || a.created_at.localeCompare(b.created_at) || a.id.localeCompare(b.id),
      )
      const representativePets = new Map<string, typeof sortedPets[number]>()
      for (const pet of sortedPets) {
        if (!representativePets.has(pet.owner_id)) representativePets.set(pet.owner_id, pet)
      }
      const representativeIds = [...representativePets.values()].map(pet => pet.id)
      const { data: cosmeticData } = representativeIds.length
        ? await supabase.from('pet_cosmetics')
          .select('pet_id,frame:shop_items!pet_cosmetics_frame_item_id_fkey(style_key),background:shop_items!pet_cosmetics_background_item_id_fkey(style_key)')
          .in('pet_id', representativeIds)
        : { data: [] }
      const cosmeticMap = new Map((cosmeticData || []).map((row: any) => [row.pet_id, {
        frame: row.frame?.style_key || null, background: row.background?.style_key || null,
      }]))
      leaderboard.value = result.entries.map(entry => {
        const pet = representativePets.get(entry.id)
        return { ...entry, pet_id: pet?.id, pet_species: pet?.species, pet_name: pet?.name || '未领养', pet_level: pet?.level || 0,
          cosmetics: pet ? cosmeticMap.get(pet.id) : undefined }
      })
      leaderboardWeek.value = { start: result.weekStart, end: result.weekEnd }
    } catch (error) {
      leaderboardError.value = error instanceof Error ? error.message : '排行榜加载失败'
    } finally {
      leaderboardLoading.value = false
    }
  }

  async function createStudent(username: string, password: string) {
    const authStore = useAuthStore()
    if (!authStore.user) return { data: null, error: new Error('未登录') }
    loading.value = true
    try {
      const normalizedUsername = username.trim()
      const { data: existing } = await supabase
        .from('profiles')
        .select('id')
        .eq('role', 'student')
        .eq('teacher_id', authStore.user.id)
        .eq('username', normalizedUsername)
        .maybeSingle()
      if (existing) {
        throw new Error('该班级已经有同名学生')
      }
      const hashedPwd = await hashPassword(password)
      const { data, error } = await supabase
        .from('profiles')
        .insert({
          username: normalizedUsername,
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

  async function renameStudent(studentId: string, username: string) {
    const currentTeacherId = teacherId()
    if (!currentTeacherId) return { error: new Error('未登录') }

    const normalizedUsername = username.trim()
    if (normalizedUsername.length < 2 || normalizedUsername.length > 12) {
      return { error: new Error('用户名需要 2-12 个字符') }
    }

    try {
      const { data: existing, error: existingError } = await supabase
        .from('profiles')
        .select('id')
        .eq('role', 'student')
        .eq('teacher_id', currentTeacherId)
        .eq('username', normalizedUsername)
        .neq('id', studentId)
        .maybeSingle()
      if (existingError) throw existingError
      if (existing) throw new Error('用户名已被使用')

      const { data, error } = await supabase
        .from('profiles')
        .update({ username: normalizedUsername })
        .eq('id', studentId)
        .eq('role', 'student')
        .eq('teacher_id', currentTeacherId)
        .select('id, username')
        .maybeSingle()
      if (error) throw error
      if (!data) throw new Error('学生不存在或不属于当前班级')

      const student = students.value.find(item => item.id === studentId)
      if (student) student.username = data.username
      const studentWithPets = studentsWithPets.value.find(item => item.id === studentId)
      if (studentWithPets) studentWithPets.username = data.username
      return { error: null, username: data.username }
    } catch (error: any) {
      return { error }
    }
  }

  async function renamePetForStudent(studentId: string, petId: string, name: string) {
    const currentTeacherId = teacherId()
    if (!currentTeacherId) return { error: new Error('未登录') }

    const normalizedName = name.trim()
    if (!normalizedName || normalizedName.length > 10) {
      return { error: new Error('宠物名字需要 1-10 个字符') }
    }

    const { data: ownedStudent, error: studentError } = await supabase
      .from('profiles')
      .select('id')
      .eq('id', studentId)
      .eq('role', 'student')
      .eq('teacher_id', currentTeacherId)
      .maybeSingle()
    if (studentError) return { error: studentError }
    if (!ownedStudent) return { error: new Error('该学生不属于当前老师') }

    const { data, error } = await supabase
      .from('pets')
      .update({ name: normalizedName })
      .eq('id', petId)
      .eq('owner_id', studentId)
      .select('id, name')
      .maybeSingle()
    if (error) return { error }
    if (!data) return { error: new Error('宠物不存在或不属于该学生') }

    const targetStudent = studentsWithPets.value.find(student => student.id === studentId)
    const targetPet = targetStudent?.pets.find(pet => pet.id === petId)
    if (targetPet) targetPet.name = data.name
    return { error: null, name: data.name }
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

    const { data, error } = await supabase.rpc('teacher_award_total', { p_teacher_id: currentTeacherId })
    if (!error) totalPointsGiven.value = Number(data ?? 0)
  }

  async function fetchStudentCosmetics(studentId: string) {
    const currentTeacherId = teacherId()
    if (!currentTeacherId) throw new Error('未登录')
    const student = studentsWithPets.value.find(item => item.id === studentId)
    if (!student) throw new Error('该学生不属于当前老师')
    const [catalog, owned] = await Promise.all([
      supabase.from('shop_items').select('*').eq('is_active', true).order('sort_order'),
      supabase.from('user_items').select('item_id').eq('user_id', studentId),
    ])
    if (catalog.error?.code === '42P01') throw new Error('商城尚未启用，请先执行数据库迁移')
    if (catalog.error || owned.error) throw catalog.error || owned.error
    cosmeticItems.value = (catalog.data || []) as ShopItem[]
    cosmeticOwnedIds.value = (owned.data || []).map(row => row.item_id)
  }

  async function purchaseCosmeticForStudent(studentId: string, petId: string, item: ShopItem) {
    const currentTeacherId = teacherId()
    if (!currentTeacherId) throw new Error('未登录')
    const result = await classroomRpc<{ balance: number; alreadyOwned: boolean }>('teacher_purchase_shop_item', {
      p_actor_id: currentTeacherId, p_student_id: studentId, p_item_id: item.id, p_request_id: crypto.randomUUID(),
    })
    const student = studentsWithPets.value.find(entry => entry.id === studentId)
    if (student) student.points = result.balance
    if (!cosmeticOwnedIds.value.includes(item.id)) cosmeticOwnedIds.value.push(item.id)
    await equipCosmeticForStudent(studentId, petId, item.category, item)
    return result
  }

  async function equipCosmeticForStudent(studentId: string, petId: string, category: 'frame' | 'background', item: ShopItem | null) {
    const currentTeacherId = teacherId()
    if (!currentTeacherId) throw new Error('未登录')
    await classroomRpc('teacher_equip_pet_cosmetic', {
      p_actor_id: currentTeacherId, p_student_id: studentId, p_pet_id: petId,
      p_category: category, p_item_id: item?.id || null,
    })
    const student = studentsWithPets.value.find(entry => entry.id === studentId)
    const pet = student?.pets.find(entry => entry.id === petId)
    if (pet) pet.cosmetics = { ...pet.cosmetics, [category]: item?.style_key || null }
  }

  return { students, studentsWithPets, leaderboardError, leaderboardLoading, leaderboardWeek, leaderboard, loading, totalStudents, totalPointsGiven, cosmeticItems, cosmeticOwnedIds, fetchStudents, fetchStudentsWithPets, performActionForStudent, fetchStudentDetail, fetchLeaderboard, fetchStats, fetchStudentCosmetics, purchaseCosmeticForStudent, equipCosmeticForStudent, createStudent, renameStudent, adoptPetForStudent, renamePetForStudent, deleteStudent }
})

if (import.meta.hot) {
  import.meta.hot.accept(acceptHMRUpdate(useTeacherStore, import.meta.hot))
}
