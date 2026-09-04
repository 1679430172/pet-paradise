import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { supabase } from '../lib/supabase'
import { classroomRpc } from '../lib/classroomApi'
import { useAuthStore } from './auth'
import type { CosmeticCategory, CosmeticSelection } from '../lib/cosmetics'

export interface ShopItem {
  id: string
  slug: string
  name: string
  description: string
  category: CosmeticCategory
  style_key: string
  price: number
  icon: string
  sort_order: number
}

export interface ShopOrder {
  id: string
  item_id: string
  price: number
  balance_after: number
  created_at: string
  item?: Pick<ShopItem, 'name' | 'icon' | 'category' | 'style_key'>
}

export const useShopStore = defineStore('shop', () => {
  const items = ref<ShopItem[]>([])
  const ownedIds = ref<string[]>([])
  const orders = ref<ShopOrder[]>([])
  const equipment = ref<Record<string, CosmeticSelection>>({})
  const loading = ref(false)
  const busyItemId = ref<string | null>(null)
  const loadedUserId = ref<string | null>(null)

  const ownedItems = computed(() => items.value.filter(item => ownedIds.value.includes(item.id)))

  async function fetchAll(force = false) {
    const auth = useAuthStore()
    if (!auth.user) return
    if (!force && loadedUserId.value === auth.user.id && items.value.length) return
    loading.value = true
    try {
      const [catalog, owned, history, equipped] = await Promise.all([
        supabase.from('shop_items').select('*').eq('is_active', true).order('sort_order'),
        supabase.from('user_items').select('item_id').eq('user_id', auth.user.id),
        supabase.from('shop_orders').select('id,item_id,price,balance_after,created_at,item:shop_items(name,icon,category,style_key)').eq('buyer_id', auth.user.id).order('created_at', { ascending: false }),
        supabase.from('pet_cosmetics').select('pet_id,frame:shop_items!pet_cosmetics_frame_item_id_fkey(style_key),background:shop_items!pet_cosmetics_background_item_id_fkey(style_key)'),
      ])
      if (catalog.error?.code === '42P01') throw new Error('商城尚未启用，请先执行数据库迁移')
      const firstError = catalog.error || owned.error || history.error || equipped.error
      if (firstError) throw firstError
      items.value = (catalog.data || []) as ShopItem[]
      ownedIds.value = (owned.data || []).map(row => row.item_id)
      orders.value = (history.data || []) as unknown as ShopOrder[]
      equipment.value = Object.fromEntries((equipped.data || []).map((row: any) => [row.pet_id, {
        frame: row.frame?.style_key || null,
        background: row.background?.style_key || null,
      }]))
      loadedUserId.value = auth.user.id
    } finally {
      loading.value = false
    }
  }

  async function purchase(item: ShopItem) {
    const auth = useAuthStore()
    if (!auth.user || busyItemId.value) return
    busyItemId.value = item.id
    try {
      const result = await classroomRpc<{ balance: number; alreadyOwned: boolean }>('purchase_shop_item', {
        p_buyer_id: auth.user.id, p_item_id: item.id, p_request_id: crypto.randomUUID(),
      })
      auth.user.points = result.balance
      await fetchAll(true)
      return result
    } finally { busyItemId.value = null }
  }

  async function equip(petId: string, category: CosmeticCategory, item: ShopItem | null) {
    const auth = useAuthStore()
    if (!auth.user) throw new Error('未登录')
    busyItemId.value = item?.id || `remove-${category}`
    try {
      await classroomRpc('equip_pet_cosmetic', {
        p_actor_id: auth.user.id, p_pet_id: petId, p_category: category, p_item_id: item?.id || null,
      })
      equipment.value[petId] = { ...equipment.value[petId], [category]: item?.style_key || null }
    } finally { busyItemId.value = null }
  }

  function selectionForPet(petId?: string | null) {
    return petId ? equipment.value[petId] || null : null
  }

  return { items, ownedIds, ownedItems, orders, equipment, loading, busyItemId, fetchAll, purchase, equip, selectionForPet }
})
