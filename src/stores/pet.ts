import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from './auth'
import { feedPet } from '../lib/classroomApi'
import { LEVEL_THRESHOLDS, STAT_DECAY_PER_HOUR, MAX_LEVEL, getFeedingReply } from '../lib/constants'

export interface Pet {
  id: string
  owner_id: string
  name: string
  species: string
  appearance: { color: string; accessory?: string; background?: string }
  level: number
  xp: number
  hunger: number
  happiness: number
  cleanliness: number
  last_fed_at: string | null
  last_played_at: string | null
  last_cleaned_at: string | null
  badges: string[]
  created_at: string
}

const CURRENT_PET_KEY = 'pet_current_id'

export const usePetStore = defineStore('pet', () => {
  const pets = ref<Pet[]>([])
  const currentPetId = ref<string | null>(localStorage.getItem(CURRENT_PET_KEY))
  const loading = ref(false)

  const currentPet = computed<Pet | null>(() => {
    if (pets.value.length === 0) return null
    if (currentPetId.value) {
      const found = pets.value.find(p => p.id === currentPetId.value)
      if (found) return found
    }
    // 默认选中：第一只未达 20 级的，否则最新一只
    const alive = pets.value.find(p => p.level < MAX_LEVEL)
    return alive || pets.value[0]
  })

  // 向后兼容：pet 作为 currentPet 的别名
  const pet = computed<Pet | null>(() => currentPet.value)

  const canAdoptNew = computed(() => {
    return pets.value.length === 0 || pets.value.every(p => p.level >= MAX_LEVEL)
  })

  function selectPet(id: string) {
    if (pets.value.some(p => p.id === id)) {
      currentPetId.value = id
      localStorage.setItem(CURRENT_PET_KEY, id)
    }
  }

  async function fetchPets() {
    const authStore = useAuthStore()
    if (!authStore.user) return
    loading.value = true
    const { data } = await supabase
      .from('pets')
      .select('*')
      .eq('owner_id', authStore.user.id)
      .order('created_at', { ascending: true })
    pets.value = data || []
    applyStatDecayAll()
    // 修正 currentPetId
    if (currentPetId.value && !pets.value.some(p => p.id === currentPetId.value)) {
      currentPetId.value = null
      localStorage.removeItem(CURRENT_PET_KEY)
    }
    if (!currentPetId.value && currentPet.value) {
      currentPetId.value = currentPet.value.id
      localStorage.setItem(CURRENT_PET_KEY, currentPet.value.id)
    }
    loading.value = false
  }

  // 兼容旧调用
  async function fetchPet() {
    await fetchPets()
  }

  function applyStatDecayAll() {
    const now = Date.now()
    const decayField = (referenceAt: string | null, currentVal: number) => {
      if (!referenceAt) return currentVal
      const elapsed = now - new Date(referenceAt).getTime()
      const hours = Math.floor(elapsed / (60 * 60 * 1000))
      const decay = Math.floor(Math.max(0, hours) * STAT_DECAY_PER_HOUR)
      return Math.max(0, currentVal - decay)
    }
    pets.value.forEach(p => {
      p.hunger = decayField(p.last_fed_at || p.created_at, p.hunger)
    })
  }

  async function createPet(name: string, species: string, color: string) {
    const authStore = useAuthStore()
    if (!authStore.user) return { data: null, error: new Error('未登录') }
    if (!canAdoptNew.value) {
      return { data: null, error: new Error('当前宠物未达完全体（Lv.20），暂不能领养新宠物') }
    }
    loading.value = true
    const { data, error } = await supabase
      .from('pets')
      .insert({
        owner_id: authStore.user.id,
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
    if (!error && data) {
      pets.value = [...pets.value, data]
      currentPetId.value = data.id
      localStorage.setItem(CURRENT_PET_KEY, data.id)
    }
    loading.value = false
    return { data, error }
  }

  const feeding = new Set<string>()
  async function performAction(action: 'basic' | 'nice' | 'luxury') {
    const target = currentPet.value
    const authStore = useAuthStore()
    if (!target || !authStore.user) return { success: false, message: '没有宠物或未登录' }
    if (feeding.has(target.owner_id)) return { success: false, message: '正在投喂，请稍候' }
    feeding.add(target.owner_id)
    try {
      const oldLevel = target.level
      const result = await feedPet(authStore.user.id, target.owner_id, target.id, action)
      Object.assign(target, result.pet)
      authStore.user.points = result.points
      return { success: true, message: getLevelUpMessage(oldLevel, target.level) || '投喂成功',
        reply: getFeedingReply(action), leveledUp: result.leveledUp }
    } catch (error) {
      return { success: false, message: error instanceof Error ? error.message : '投喂失败' }
    } finally {
      feeding.delete(target.owner_id)
    }
  }

  function calculateLevel(xp: number): number {
    for (let i = LEVEL_THRESHOLDS.length - 1; i >= 0; i--) {
      if (xp >= LEVEL_THRESHOLDS[i]) return Math.min(MAX_LEVEL, i + 1)
    }
    return 1
  }

  function getLevelUpMessage(oldLevel: number, newLevel: number): string {
    if (newLevel > oldLevel) {
      if (newLevel >= MAX_LEVEL) return '进化为完全体！可领养新宠物了'
      return `升级了！宠物达到 ${newLevel} 级！`
    }
    return ''
  }

  async function addXp(amount: number) {
    if (amount <= 0) return
    const target = currentPet.value
    if (!target) return
    const newXp = target.xp + amount
    const newLevel = calculateLevel(newXp)
    await supabase
      .from('pets')
      .update({ xp: newXp, level: newLevel })
      .eq('id', target.id)
    target.xp = newXp
    target.level = newLevel
  }

  return {
    pets,
    pet,
    currentPet,
    currentPetId,
    canAdoptNew,
    loading,
    fetchPet,
    fetchPets,
    createPet,
    performAction,
    addXp,
    selectPet,
  }
})
