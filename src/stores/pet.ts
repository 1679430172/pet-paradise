import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from './auth'
import { usePointsStore } from './points'
import { ACTIONS, LEVEL_THRESHOLDS, STAT_DECAY_PER_HOUR, MAX_LEVEL } from '../lib/constants'

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
    const decayField = (lastAt: string | null, currentVal: number) => {
      if (!lastAt) return currentVal
      const elapsed = now - new Date(lastAt).getTime()
      const hours = Math.floor(elapsed / (60 * 60 * 1000))
      return Math.max(0, currentVal - hours * STAT_DECAY_PER_HOUR)
    }
    pets.value.forEach(p => {
      p.hunger = decayField(p.last_fed_at, p.hunger)
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

  async function performAction(action: 'basic' | 'nice' | 'luxury') {
    const target = currentPet.value
    if (!target) return { success: false, message: '没有宠物' }
    if (target.level >= MAX_LEVEL) {
      // 允许继续操作但不再升级，也可提示
    }

    const pointsStore = usePointsStore()
    const cost = pointsStore.actionCosts[action]
    const authStore = useAuthStore()

    if (!authStore.user || authStore.user.points < cost) {
      return { success: false, message: `积分不足，需要 ${cost} 积分` }
    }

    // 扣积分
    const spent = await pointsStore.spendPoints(cost)
    if (!spent) {
      return { success: false, message: '扣积分失败' }
    }

    const config = ACTIONS[action]
    const newStatVal = Math.min(100, target.hunger + config.statGain)
    const newXp = target.xp + config.xp
    const oldLevel = target.level
    const newLevel = calculateLevel(newXp)
    const now = new Date().toISOString()

    const updates: any = {
      hunger: newStatVal,
      last_fed_at: now,
      xp: newXp,
      level: newLevel,
    }

    const { error } = await supabase
      .from('pets')
      .update(updates)
      .eq('id', target.id)

    if (!error) {
      Object.assign(target, updates)
      return { success: true, message: getLevelUpMessage(oldLevel, newLevel) }
    }
    return { success: false, message: '操作失败' }
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
    return '操作成功！'
  }

  async function addXp(amount: number) {
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
