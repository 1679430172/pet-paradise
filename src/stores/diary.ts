import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from './auth'
import { usePetStore } from './pet'
import { classroomRpc } from '../lib/classroomApi'

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

  async function createEntry(entry: {
    title: string; content: string; image_url?: string | null; mood: string; is_public: boolean
  }) {
    const authStore = useAuthStore()
    const petStore = usePetStore()
    if (!authStore.user || !petStore.pet) return { error: '未登录' }
    try {
      const result = await classroomRpc<{ entry: DiaryEntry; points: number; reward: number }>('publish_diary', {
        p_actor_id: authStore.user.id, p_pet_id: petStore.pet.id,
        p_entry: entry, p_request_id: crypto.randomUUID(),
      })
      entries.value.unshift(result.entry)
      authStore.user.points = result.points
      return { data: result.entry, error: null, earnedPoints: result.reward > 0 }
    } catch (error) {
      return { data: null, error: error instanceof Error ? error.message : '发布失败', earnedPoints: false }
    }
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
