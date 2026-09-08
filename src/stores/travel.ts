import { defineStore } from 'pinia'
import { ref } from 'vue'
import { classroomRpc } from '../lib/classroomApi'
import { useAuthStore } from './auth'
import type { ShopItem } from './shop'

export interface Destination { id: string; name: string; icon: string; description: string; hours: number; stories: string[] }
export interface TravelItem extends ShopItem { destination_id: string; stamp_cost: number; owned: boolean }
export interface TravelReward { story: string; stamps: number; duplicate: boolean; item: ShopItem | null }
export interface TravelPetSnapshot { id: string; name: string; species: string; level: number; stage: 'egg' | 'baby' | 'teen' | 'adult' | 'final'; appearance?: unknown }
export interface TravelPostcard { id?: string; destination_id: string; story: string; pet_snapshot?: TravelPetSnapshot | null; pet_id?: string | null; pet_name?: string | null; source?: 'trip' | 'gift' | 'legacy'; collected_at?: string }
export interface Trip { id: string; pet_id: string | null; pet_name: string; pet_snapshot?: TravelPetSnapshot | null; destination_id: string; started_at: string; returns_at: string; claimed_at: string | null; reward: TravelReward | null }
export interface TravelState {
  serverNow: string; canDepart: boolean; stamps: number; tickets: number
  destinations: Destination[]; items: TravelItem[]; active: Trip | null; activeTrips?: Trip[]; history: Trip[]
  postcards: TravelPostcard[]
}

export const useTravelStore = defineStore('travel', () => {
  const state = ref<TravelState | null>(null)
  const loading = ref(false)
  const busy = ref(false)
  const error = ref('')
  let loadedUserId: string | null = null
  let receivedAt = 0
  const userId = () => { const id = useAuthStore().user?.id; if (!id) throw new Error('请先登录'); return id }
  const message = (e: unknown) => e instanceof Error ? e.message.replace('课堂功能数据库迁移', '旅行数据库迁移') : '旅行加载失败，请重试'
  // 使用服务器时间和单调时钟，系统时钟调整不会改变旅行倒计时。
  function serverTime() { return state.value ? Date.parse(state.value.serverNow) + performance.now() - receivedAt : 0 }
  async function refresh() {
    if (!useAuthStore().hasFeature('travel')) throw new Error('本班级尚未开通旅游功能')
    const id = userId()
    if (loadedUserId !== id) state.value = null
    loading.value = true
    error.value = ''
    try {
      const data = await classroomRpc<TravelState>('travel_state', { p_user_id: id })
      if (!Number.isInteger(data.tickets)) throw new Error('旅行券功能尚未启用，请先执行旅行券数据库迁移')
      if (useAuthStore().user?.id !== id) return
      state.value = data; receivedAt = performance.now(); loadedUserId = id
    } catch (e) { error.value = message(e); throw e }
    finally { loading.value = false }
  }
  async function act<T>(name: string, args: Record<string, unknown>) {
    if (!useAuthStore().hasFeature('travel')) throw new Error('本班级尚未开通旅游功能')
    if (busy.value) throw new Error('正在处理，请稍候')
    busy.value = true
    try {
      const result = await classroomRpc<T>(name, { p_user_id: userId(), ...args })
      // 已成功的结算不因后续读取失败被提示为失败；页面保留刷新入口。
      await refresh().catch(() => undefined)
      return result
    } catch (e) { throw new Error(message(e)) }
    finally { busy.value = false }
  }
  const start = (petId: string, destinationId: string) => act<Trip>('start_pet_trip', { p_pet_id: petId, p_destination_id: destinationId, p_request_id: crypto.randomUUID() })
  const claim = (tripId: string) => act<TravelReward>('claim_pet_trip', { p_trip_id: tripId })
  const redeem = (itemId: string) => act<{ alreadyOwned: boolean }>('redeem_travel_item', { p_item_id: itemId })
  return { state, loading, busy, error, refresh, serverTime, start, claim, redeem }
})
