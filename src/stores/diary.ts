import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from './auth'
import { usePetStore } from './pet'
import { usePointsStore } from './points'
import { DIARY_XP, PHOTO_XP } from '../lib/constants'

export interface DiaryEntry {
  id: string
  owner_id: string
  pet_id: string
  title: string
  content: string
  image_url: string | null
  mood: string
  is_public: boolean
  created_at: string
}

export const useDiaryStore = defineStore('diary', () => {
  const entries = ref<DiaryEntry[]>([])
  const loading = ref(false)

  async function fetchMyEntries() {
    const authStore = useAuthStore()
    if (!authStore.user) return
    loading.value = true
    const { data } = await supabase
      .from('diary_entries')
      .select('*')
      .eq('owner_id', authStore.user.id)
      .order('created_at', { ascending: false })
    entries.value = data ?? []
    loading.value = false
  }

  async function isFirstDiaryToday(): Promise<boolean> {
    const authStore = useAuthStore()
    if (!authStore.user) return false

    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const todayISO = today.toISOString()

    const { count } = await supabase
      .from('diary_entries')
      .select('id', { count: 'exact', head: true })
      .eq('owner_id', authStore.user.id)
      .gte('created_at', todayISO)

    return (count ?? 0) === 0
  }

  async function createEntry(entry: {
    title: string
    content: string
    image_url?: string | null
    mood: string
    is_public: boolean
  }) {
    const authStore = useAuthStore()
    const petStore = usePetStore()
    const pointsStore = usePointsStore()
    if (!authStore.user || !petStore.pet) return { error: '未登录' }

    // 先检查是否是今天第一篇
    const firstToday = await isFirstDiaryToday()

    const { data, error } = await supabase
      .from('diary_entries')
      .insert({
        owner_id: authStore.user.id,
        pet_id: petStore.pet.id,
        ...entry,
      })
      .select()
      .single()

    if (!error && data) {
      entries.value.unshift(data)
      // 奖励经验值
      let xp = DIARY_XP
      if (entry.image_url) xp += PHOTO_XP
      await petStore.addXp(xp)

      // 每天第一篇日记奖励积分
      if (firstToday) {
        await pointsStore.fetchDiaryPoints()
        await pointsStore.earnPoints(pointsStore.diaryPoints)
      }
    }
    return { data, error, earnedPoints: firstToday ? true : false }
  }

  async function deleteEntry(id: string) {
    await supabase.from('diary_entries').delete().eq('id', id)
    entries.value = entries.value.filter(e => e.id !== id)
  }

  async function uploadImage(file: File): Promise<string | null> {
    const authStore = useAuthStore()
    if (!authStore.user) return null

    const ext = file.name.split('.').pop()
    const path = `${authStore.user.id}/${Date.now()}.${ext}`
    const { error } = await supabase.storage
      .from('diary-images')
      .upload(path, file, { contentType: file.type })

    if (error) return null
    const { data } = supabase.storage.from('diary-images').getPublicUrl(path)
    return data.publicUrl
  }

  return { entries, loading, fetchMyEntries, createEntry, deleteEntry, uploadImage }
})
