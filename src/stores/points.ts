import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { DEFAULT_ACTION_COSTS } from '../lib/constants'

export interface ActionCosts {
  basic: number
  nice: number
  luxury: number
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
      const v = data.value as any
      // 兼容旧格式 {feed, play, clean}：检测到旧字段则回退到默认值
      if (typeof v.basic === 'number' || typeof v.nice === 'number' || typeof v.luxury === 'number') {
        actionCosts.value = {
          basic: v.basic ?? DEFAULT_ACTION_COSTS.basic,
          nice: v.nice ?? DEFAULT_ACTION_COSTS.nice,
          luxury: v.luxury ?? DEFAULT_ACTION_COSTS.luxury,
        }
      } else {
        actionCosts.value = { ...DEFAULT_ACTION_COSTS }
      }
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

  return { actionCosts, diaryPoints, loading, fetchActionCosts, fetchDiaryPoints, updateActionCosts, updateDiaryPoints }
})
