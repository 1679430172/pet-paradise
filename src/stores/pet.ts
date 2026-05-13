import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from './auth'
import { usePointsStore } from './points'
import { ACTIONS, LEVEL_THRESHOLDS, STAT_DECAY_PER_HOUR } from '../lib/constants'

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

export const usePetStore = defineStore('pet', () => {
  const pet = ref<Pet | null>(null)
  const loading = ref(false)

  async function fetchPet() {
    const authStore = useAuthStore()
    if (!authStore.user) return
    loading.value = true
    const { data } = await supabase
      .from('pets')
      .select('*')
      .eq('owner_id', authStore.user.id)
      .single()
    if (data) {
      pet.value = data
      applyStatDecay()
    }
    loading.value = false
  }

  function applyStatDecay() {
    if (!pet.value) return
    const now = Date.now()

    const decayField = (lastAt: string | null, currentVal: number) => {
      if (!lastAt) return currentVal
      const elapsed = now - new Date(lastAt).getTime()
      const hours = Math.floor(elapsed / (60 * 60 * 1000))
      return Math.max(0, currentVal - hours * STAT_DECAY_PER_HOUR)
    }

    pet.value.hunger = decayField(pet.value.last_fed_at, pet.value.hunger)
    pet.value.happiness = decayField(pet.value.last_played_at, pet.value.happiness)
    pet.value.cleanliness = decayField(pet.value.last_cleaned_at, pet.value.cleanliness)
  }

  async function createPet(name: string, species: string, color: string) {
    const authStore = useAuthStore()
    if (!authStore.user) return
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
      pet.value = data
    }
    loading.value = false
    return { data, error }
  }

  async function performAction(action: 'feed' | 'play' | 'clean') {
    if (!pet.value) return { success: false, message: '没有宠物' }

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

    // 计算新值
    const config = ACTIONS[action]
    const statKey = config.statKey
    const newStatVal = Math.min(100, pet.value[statKey] + config.statGain)
    const newXp = pet.value.xp + config.xp
    const newLevel = calculateLevel(newXp)
    const now = new Date().toISOString()
    const lastAtKey = action === 'feed' ? 'last_fed_at' : action === 'play' ? 'last_played_at' : 'last_cleaned_at'

    const updates: any = {
      [statKey]: newStatVal,
      [lastAtKey]: now,
      xp: newXp,
      level: newLevel,
    }

    const { error } = await supabase
      .from('pets')
      .update(updates)
      .eq('id', pet.value.id)

    if (!error) {
      Object.assign(pet.value, updates)
      return { success: true, message: getLevelUpMessage(pet.value.level, newLevel) }
    }
    return { success: false, message: '操作失败' }
  }

  function calculateLevel(xp: number): number {
    for (let i = LEVEL_THRESHOLDS.length - 1; i >= 0; i--) {
      if (xp >= LEVEL_THRESHOLDS[i]) return i + 1
    }
    return 1
  }

  function getLevelUpMessage(oldLevel: number, newLevel: number): string {
    if (newLevel > oldLevel) {
      return `升级了！宠物达到 ${newLevel} 级！`
    }
    return '操作成功！'
  }

  async function addXp(amount: number) {
    if (!pet.value) return
    const newXp = pet.value.xp + amount
    const newLevel = calculateLevel(newXp)
    await supabase
      .from('pets')
      .update({ xp: newXp, level: newLevel })
      .eq('id', pet.value.id)
    pet.value.xp = newXp
    pet.value.level = newLevel
  }

  return { pet, loading, fetchPet, createPet, performAction, addXp }
})
