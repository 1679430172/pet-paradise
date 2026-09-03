import { supabase } from './supabase'
import type { Pet } from '../stores/pet'
import type { ActionKey } from './constants'

// 一次用户操作固定一个请求编号；传输失败重试也不会再次扣分或发奖励。
export async function classroomRpc<T>(name: string, args: Record<string, unknown>): Promise<T> {
  let result = await supabase.rpc(name, args)
  if (result.error && (!result.status || result.status >= 500)) {
    result = await supabase.rpc(name, args)
  }
  if (result.error) {
    if (result.error.code === 'PGRST202') throw new Error('功能尚未启用，请先执行课堂功能数据库迁移')
    throw new Error(result.error.message || '请求失败，请刷新后确认结果')
  }
  if (!result.data) throw new Error('未收到操作结果，请刷新后确认')
  return result.data as T
}

export interface FeedResult {
  points: number
  pet: Pet
  cost: number
  leveledUp: boolean
}

export function feedPet(actorId: string, studentId: string, petId: string, action: ActionKey) {
  return classroomRpc<FeedResult>('feed_pet', {
    p_actor_id: actorId, p_student_id: studentId, p_pet_id: petId,
    p_action: action, p_request_id: crypto.randomUUID(),
  })
}
