import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from './auth'
import { LIKE_XP } from '../lib/constants'

export interface FeedItem {
  id: string
  title: string
  content: string
  image_url: string | null
  mood: string
  created_at: string
  owner_id: string
  profiles: { username: string; avatar_url: string | null }
  pets: { name: string; species: string; appearance: any; level: number }
  likes_count: number
  liked_by_me: boolean
}

export const useFeedStore = defineStore('feed', () => {
  const items = ref<FeedItem[]>([])
  const loading = ref(false)

  async function fetchFeed() {
    const authStore = useAuthStore()
    if (!authStore.user) return
    const currentTeacherId = authStore.isTeacher ? authStore.user.id : authStore.user.teacher_id
    if (!currentTeacherId) {
      items.value = []
      return
    }
    loading.value = true

    const { data } = await supabase
      .from('diary_entries')
      .select(`
        *,
        profiles:owner_id!inner(username, avatar_url, teacher_id),
        pets:pet_id(name, species, appearance, level)
      `)
      .eq('is_public', true)
      .eq('profiles.teacher_id', currentTeacherId)
      .order('created_at', { ascending: false })
      .limit(50)

    if (data && authStore.user) {
      // 查询当前用户的点赞记录
      const { data: myLikes } = await supabase
        .from('likes')
        .select('diary_id')
        .eq('user_id', authStore.user.id)
      const likedIds = new Set(myLikes?.map(l => l.diary_id) ?? [])

      // 查询每篇日记的点赞数
      const diaryIds = data.map(d => d.id)
      const { data: likeCounts } = await supabase
        .from('likes')
        .select('diary_id')
        .in('diary_id', diaryIds)

      const countMap: Record<string, number> = {}
      likeCounts?.forEach(l => {
        countMap[l.diary_id] = (countMap[l.diary_id] || 0) + 1
      })

      items.value = data.map(item => ({
        ...item,
        likes_count: countMap[item.id] || 0,
        liked_by_me: likedIds.has(item.id),
      }))
    }
    loading.value = false
  }

  async function toggleLike(diaryId: string, ownerId: string) {
    const authStore = useAuthStore()
    if (!authStore.user) return

    const item = items.value.find(i => i.id === diaryId)
    if (!item) return

    if (item.liked_by_me) {
      await supabase
        .from('likes')
        .delete()
        .eq('user_id', authStore.user.id)
        .eq('diary_id', diaryId)
      item.liked_by_me = false
      item.likes_count--
    } else {
      await supabase
        .from('likes')
        .insert({ user_id: authStore.user.id, diary_id: diaryId })
      item.liked_by_me = true
      item.likes_count++

      // 给被赞的宠物主人加经验（如果不是自己）
      if (LIKE_XP > 0 && ownerId !== authStore.user.id) {
        const { data: ownerPet } = await supabase
          .from('pets')
          .select('id, xp, level')
          .eq('owner_id', ownerId)
          .single()
        if (ownerPet) {
          const newXp = ownerPet.xp + LIKE_XP
          await supabase
            .from('pets')
            .update({ xp: newXp })
            .eq('id', ownerPet.id)
        }
      }
    }
  }

  return { items, loading, fetchFeed, toggleLike }
})
