import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from './auth'
import { DEFAULT_ACTION_COSTS } from '../lib/constants'

export interface ActionCosts {
  feed: number
  play: number
  clean: number
}

export const usePointsStore = defineStore('points', () => {
  const actionCosts = ref<ActionCosts>({ ...DEFAULT_ACTION_COSTS })
  const diaryPoints = ref(5)
  const loading = ref(false)

  async function fetchActionCosts() {
    const { data } = await supabase
      .from('settings')
      .select('value')
      .eq('key', 'action_costs')
      .single()
    if (data?.value) {
      actionCosts.value = data.value as ActionCosts
    }
  }

  async function fetchDiaryPoints() {
    const { data } = await supabase
      .from('settings')
      .select('value')
      .eq('key', 'diary_points')
      .single()
    if (data?.value) {
      diaryPoints.value = (data.value as any).points ?? 5
    }
  }

  async function updateActionCosts(costs: ActionCosts) {
    loading.value = true
    try {
      const { error } = await supabase
        .from('settings')
        .update({ value: costs, updated_at: new Date().toISOString() })
        .eq('key', 'action_costs')
      if (error) throw error
      actionCosts.value = costs
      return { error: null }
    } catch (error: any) {
      return { error }
    } finally {
      loading.value = false
    }
  }

  async function updateDiaryPoints(points: number) {
    loading.value = true
    try {
      const { error } = await supabase
        .from('settings')
        .upsert({ key: 'diary_points', value: { points }, updated_at: new Date().toISOString() }, { onConflict: 'key' })
      if (error) throw error
      diaryPoints.value = points
      return { error: null }
    } catch (error: any) {
      return { error }
    } finally {
      loading.value = false
    }
  }

  async function earnPoints(amount: number) {
    const authStore = useAuthStore()
    if (!authStore.user) return false

    const newPoints = authStore.user.points + amount
    const { error } = await supabase
      .from('profiles')
      .update({ points: newPoints })
      .eq('id', authStore.user.id)

    if (!error) {
      authStore.user.points = newPoints
      return true
    }
    return false
  }

  async function spendPoints(amount: number) {
    const authStore = useAuthStore()
    if (!authStore.user) return false
    if (authStore.user.points < amount) return false

    const newPoints = authStore.user.points - amount
    const { error } = await supabase
      .from('profiles')
      .update({ points: newPoints })
      .eq('id', authStore.user.id)

    if (!error) {
      authStore.user.points = newPoints
      return true
    }
    return false
  }

  return { actionCosts, diaryPoints, loading, fetchActionCosts, fetchDiaryPoints, updateActionCosts, updateDiaryPoints, earnPoints, spendPoints }
})
