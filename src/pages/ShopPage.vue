<template>
  <main class="page shop-page">
    <header class="shop-header">
      <div><span class="eyebrow">宠物装扮屋</span><h1>我的小商城</h1><p>把每一份努力，换成宠物的独特模样。</p></div>
      <div class="shop-balance"><span class="balance-mark">积分</span><strong>{{ authStore.user?.points || 0 }}</strong><small>可用余额</small></div>
    </header>

    <div v-if="notice" class="shop-notice" :class="{ error: noticeError }" role="status">{{ notice }}</div>
    <div v-if="shopStore.loading" class="loading-state">正在打开商城...</div>
    <template v-else>
      <section v-if="petStore.currentPet" class="wardrobe">
        <div class="wardrobe-copy"><span class="section-tag">当前试穿</span><h2>{{ petStore.currentPet.name }}</h2><p>边框和背景可以自由搭配</p></div>
        <div class="pet-preview cosmetic-card" :class="previewClasses" :style="getPetThemeStyle(petStore.currentPet.appearance.color)">
          <div class="preview-card-head"><span>{{ petStore.currentPet.name }}</span><strong>Lv.{{ petStore.currentPet.level }}</strong></div>
          <div class="preview-pet-stage"><PetAvatar :species="petStore.currentPet.species" :level="petStore.currentPet.level" :size="150" show-stage /></div>
          <div class="preview-card-stats">
            <div><span>饱食</span><b>{{ Math.round(petStore.currentPet.hunger) }}</b></div>
            <div class="preview-stat-track"><i :style="{ width: `${petStore.currentPet.hunger}%` }"></i></div>
            <div><span>成长</span><b>{{ petStore.currentPet.level >= 20 ? '满级' : `${Math.round(petXpProgress)}%` }}</b></div>
            <div class="preview-stat-track xp"><i :style="{ width: `${petXpProgress}%` }"></i></div>
          </div>
        </div>
        <div class="preview-meta"><span class="equipped-kicker">正在使用</span><strong>{{ equippedLabel }}</strong><small>Lv.{{ petStore.currentPet.level }} · 装扮会同步到宠物卡片</small></div>
      </section>

      <div class="catalog-heading">
        <div><span class="section-tag">精选收藏</span><h2>{{ activeTab === 'frame' ? '卡片边框' : activeTab === 'background' ? '背景主题' : '我的购买记录' }}</h2></div>
        <div class="shop-tabs" role="tablist">
          <button v-for="tab in tabs" :key="tab.key" :class="{ active: activeTab === tab.key }" @click="activeTab = tab.key">{{ tab.label }}</button>
        </div>
      </div>

      <section v-if="activeTab !== 'orders'" class="product-grid">
        <article v-for="item in visibleItems" :key="item.id" class="product-card cosmetic-card" :class="[cosmeticClasses({ [item.category]: item.style_key }), { owned: isOwned(item), equipped: isEquipped(item) }]">
          <div class="product-preview" :style="item.category === 'frame' ? getPetThemeStyle(petStore.currentPet?.appearance.color || '#d89072') : undefined">
            <PetAvatar v-if="petStore.currentPet" :species="petStore.currentPet.species" :level="petStore.currentPet.level" :size="148" show-stage />
            <span v-if="isEquipped(item)" class="equipped-ribbon">使用中</span>
          </div>
          <div class="product-copy"><div class="product-title"><h3>{{ item.name }}</h3><span v-if="isOwned(item) && !isEquipped(item)">已拥有</span></div><p>{{ item.description }}</p></div>
          <div v-if="!isEquipped(item)" class="product-price"><span>积分</span><strong>{{ item.price }}</strong></div>
          <button v-if="!isOwned(item)" class="buy-button" :disabled="shopStore.busyItemId !== null || !canAfford(item)" @click="buy(item)">
            <template v-if="shopStore.busyItemId === item.id">购买中...</template><template v-else>购买并使用</template>
          </button>
          <button v-else-if="!isEquipped(item)" class="equip-button" :disabled="!petStore.currentPet || shopStore.busyItemId !== null" @click="equip(item)">立即装备</button>
          <button v-else class="remove-button" :disabled="shopStore.busyItemId !== null" @click="remove(item.category)">已在使用 · 点击卸下</button>
        </article>
      </section>

      <section v-else class="orders card">
        <div class="orders-heading"><h2>购买记录</h2><span>共 {{ shopStore.orders.length }} 件装扮</span></div>
        <div v-if="!shopStore.orders.length" class="empty-orders"><span>暂无记录</span><p>还没有购买记录，去挑一件喜欢的装扮吧。</p></div>
        <div v-for="order in shopStore.orders" :key="order.id" class="order-row">
          <span class="order-preview cosmetic-card" :class="order.item ? cosmeticClasses({ [order.item.category]: order.item.style_key }) : []" :style="getPetThemeStyle(petStore.currentPet?.appearance.color || '#d89072')">
            <PetAvatar v-if="petStore.currentPet" :species="petStore.currentPet.species" :level="petStore.currentPet.level" :size="34" />
          </span>
          <div><strong>{{ order.item?.name || '装扮商品' }}</strong><small>{{ formatTime(order.created_at) }}{{ order.actor?.role === 'teacher' ? ` · ${order.actor.username}老师代购` : '' }}</small></div><span class="order-price">-{{ order.price }} 积分</span>
        </div>
      </section>
    </template>
  </main>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useAuthStore } from '../stores/auth'
import { usePetStore } from '../stores/pet'
import { useShopStore, type ShopItem } from '../stores/shop'
import { cosmeticClasses } from '../lib/cosmetics'
import { getPetThemeStyle } from '../lib/petTheme'
import { LEVEL_THRESHOLDS, MAX_LEVEL } from '../lib/constants'
import PetAvatar from '../components/pet/PetAvatar.vue'

const authStore = useAuthStore(), petStore = usePetStore(), shopStore = useShopStore()
const activeTab = ref<'frame' | 'background' | 'orders'>('frame')
const notice = ref(''), noticeError = ref(false)
const tabs = [{ key: 'frame', label: '卡片边框' }, { key: 'background', label: '背景' }, { key: 'orders', label: '购买记录' }] as const
const visibleItems = computed(() => shopStore.items.filter(item => item.category === activeTab.value))
const selection = computed(() => shopStore.selectionForPet(petStore.currentPet?.id))
const previewClasses = computed(() => cosmeticClasses(selection.value))
const equippedLabel = computed(() => {
  const chosen = shopStore.items.filter(item => selection.value?.[item.category] === item.style_key)
  return chosen.length ? chosen.map(item => item.name).join(' · ') : '经典卡面'
})
const petXpProgress = computed(() => {
  const pet = petStore.currentPet
  if (!pet || pet.level >= MAX_LEVEL) return 100
  const start = LEVEL_THRESHOLDS[Math.max(0, pet.level - 1)] || 0
  const end = LEVEL_THRESHOLDS[pet.level] || start + 1
  return Math.max(0, Math.min(100, ((pet.xp - start) / (end - start)) * 100))
})
const isOwned = (item: ShopItem) => shopStore.ownedIds.includes(item.id)
const isEquipped = (item: ShopItem) => selection.value?.[item.category] === item.style_key
const canAfford = (item: ShopItem) => (authStore.user?.points || 0) >= item.price

function show(message: string, error = false) { notice.value = message; noticeError.value = error; window.setTimeout(() => { notice.value = '' }, 2800) }
async function buy(item: ShopItem) {
  try {
    const result = await shopStore.purchase(item)
    if (petStore.currentPet) await shopStore.equip(petStore.currentPet.id, item.category, item)
    show(result?.alreadyOwned ? `已为 ${petStore.currentPet?.name || '宠物'} 装备「${item.name}」` : `已购买并装备「${item.name}」`)
  } catch (e) { show(e instanceof Error ? e.message : '购买失败', true) }
}
async function equip(item: ShopItem) { if (!petStore.currentPet) return; try { await shopStore.equip(petStore.currentPet.id, item.category, item); show(`已为 ${petStore.currentPet.name} 装备「${item.name}」`) } catch (e) { show(e instanceof Error ? e.message : '装备失败', true) } }
async function remove(category: 'frame' | 'background') { if (!petStore.currentPet) return; try { await shopStore.equip(petStore.currentPet.id, category, null); show(category === 'frame' ? '已卸下边框' : '已卸下背景') } catch (e) { show(e instanceof Error ? e.message : '卸下失败', true) } }
const formatTime = (value: string) => new Intl.DateTimeFormat('zh-CN', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value))

onMounted(async () => { try { await Promise.all([petStore.fetchPets(), shopStore.fetchAll(true)]) } catch (e) { show(e instanceof Error ? e.message : '商城加载失败', true) } })
</script>

<style scoped>
.shop-page { max-width: 1220px; padding-top: 32px; color: #31433d; }
.shop-header { display:flex; align-items:flex-end; justify-content:space-between; gap:24px; padding:0 4px 28px; }
.eyebrow,.section-tag { color:#a55872; font-size:.7rem; font-weight:800; letter-spacing:.16em; }
.shop-header h1 { margin:6px 0 2px; color:#314740; font-size:clamp(1.8rem,4vw,2.65rem); letter-spacing:-.04em; }
.shop-header p,.wardrobe p { color:#7c837f; font-size:.86rem; }
.shop-balance { min-width:142px; display:grid; grid-template-columns:auto 1fr; align-items:center; gap:0 12px; padding:13px 18px; border:1px solid #e7d6a4; border-radius:16px; background:#fffbec; color:#8a611c; box-shadow:0 10px 26px #74520d0d; }
.balance-mark { grid-row:1 / 3; display:grid; place-items:center; width:40px; height:40px; border-radius:50%; background:#eabf4b; color:#fff; font-size:.62rem; font-weight:800; }.shop-balance strong { font-size:1.35rem; line-height:1.1; }.shop-balance small { font-size:.65rem; color:#9b865a; }
.shop-notice { position:fixed; z-index:120; top:18px; left:50%; transform:translateX(-50%); padding:11px 18px; border-radius:999px; background:#e5f5e9; color:#2b6945; box-shadow:0 7px 22px #253b2c20; }.shop-notice.error { background:#fff0ef; color:#a13f49; }
.loading-state { padding:70px; text-align:center; color:#8b8f8b; }
.wardrobe { display:grid; grid-template-columns:minmax(180px,.75fr) minmax(220px,.8fr) minmax(210px,.8fr); align-items:center; gap:42px; min-height:390px; margin-bottom:38px; padding:30px 54px; border-block:1px solid #ede5dc; background:#fffcf8; }
.wardrobe h2 { margin:8px 0 2px; color:#344941; font-size:1.55rem; }.pet-preview { width:220px; height:320px; display:flex; flex-direction:column; justify-self:center; padding:34px 18px 20px; border:2px solid #fff; border-radius:22px; overflow:visible; box-shadow:0 4px 18px #233d3210; }.pet-preview[class*="cosmetic-frame-"]::after { inset:-5.56%; border-radius:28px; }.pet-preview.cosmetic-frame-leaf { --cosmetic-frame-image:url('/assets/shop/frame-leaf-portrait-v3.png'); }.pet-preview.cosmetic-frame-candy { --cosmetic-frame-image:url('/assets/shop/frame-candy-portrait-v3.png'); }.pet-preview.cosmetic-frame-starlight { --cosmetic-frame-image:url('/assets/shop/frame-starlight-portrait-v3.png'); }.pet-preview.cosmetic-frame-gold { --cosmetic-frame-image:url('/assets/shop/frame-gold-portrait-v3.png'); }.pet-preview :deep(.pet-avatar-wrap) { position:relative; z-index:1; }.preview-card-head { z-index:4!important; display:flex; align-items:center; justify-content:space-between; color:#536b61; font-size:.74rem; }.preview-card-head>span,.preview-card-head strong { padding:4px 8px; border-radius:999px; background:#fffffff0; box-shadow:0 2px 8px #263b3012; }.preview-card-head strong { color:#807044; font-size:.66rem; }.preview-pet-stage { flex:1; display:grid; place-items:center; min-height:0; }.preview-card-stats { z-index:4!important; padding:10px 12px; border:1px solid #ffffffb8; border-radius:14px; background:#f1f5f2ed; box-shadow:0 3px 12px #263b3010; backdrop-filter:blur(4px); }.preview-card-stats>div:not(.preview-stat-track) { display:flex; justify-content:space-between; color:#687a71; font-size:.61rem; }.preview-card-stats b { color:#496255; font-size:.62rem; }.preview-stat-track { height:5px; margin:4px 0 8px; overflow:hidden; border-radius:999px; background:#dfe7e1; }.preview-stat-track:last-child { margin-bottom:0; }.preview-stat-track i { display:block; height:100%; border-radius:inherit; background:#9abaad; }.preview-stat-track.xp i { background:#b6abd0; }.preview-meta { display:flex; flex-direction:column; align-items:flex-start; gap:7px; }.preview-meta strong { font-size:1.08rem; color:#364b43; }.preview-meta small { color:#92948f; font-size:.7rem; line-height:1.6; }.equipped-kicker { color:#7c8f54; font-size:.68rem; font-weight:800; letter-spacing:.1em; }
.catalog-heading { display:flex; justify-content:space-between; align-items:flex-end; gap:28px; margin-bottom:20px; }.catalog-heading h2 { margin-top:4px; font-size:1.35rem; color:#3b4d46; }.shop-tabs { display:flex; gap:2px; padding:4px; overflow:auto; border-radius:12px; background:#efece7; }.shop-tabs button { white-space:nowrap; padding:9px 17px; border-radius:9px; background:transparent; color:#777a77; font-size:.78rem; font-weight:650; }.shop-tabs button.active { background:#fff; color:#a25170; box-shadow:0 2px 8px #45382b0c; }
.product-grid { display:grid; grid-template-columns:repeat(auto-fill,220px); align-items:start; gap:60px 56px; padding:28px 22px; }.product-card { position:relative; isolation:isolate; display:flex; flex-direction:column; gap:6px; width:220px; height:320px; min-width:0; padding:24px 21px 19px; overflow:visible; border:2px solid #fff; border-radius:22px; background:#fffdf9; box-shadow:0 4px 18px #233d3210; transition:transform .22s ease,border-color .22s ease,box-shadow .22s ease; }.product-card[class*="cosmetic-frame-"]::after { inset:-5.56%; z-index:3; border-radius:30px; pointer-events:none; }.product-card.cosmetic-frame-leaf { --cosmetic-frame-image:url('/assets/shop/frame-leaf-portrait-v3.png'); }.product-card.cosmetic-frame-candy { --cosmetic-frame-image:url('/assets/shop/frame-candy-portrait-v3.png'); }.product-card.cosmetic-frame-starlight { --cosmetic-frame-image:url('/assets/shop/frame-starlight-portrait-v3.png'); }.product-card.cosmetic-frame-gold { --cosmetic-frame-image:url('/assets/shop/frame-gold-portrait-v3.png'); }.product-card[class*="cosmetic-frame-"] > * { position:relative; z-index:2; }.product-card:hover { transform:translateY(-3px); border-color:#e4d9ce; box-shadow:0 8px 24px #233d321c; }.product-card.equipped { border-color:#789362; box-shadow:0 0 0 3px #78936218,0 8px 24px #233d3218; }
.product-card[class*="cosmetic-background-"] { background-clip:padding-box; }
.product-card.cosmetic-background-hidden { background:#fffdf9!important; box-shadow:0 4px 18px #233d3210!important; }
.product-card.cosmetic-background-night .product-title h3 { color:#fff; }
.product-card.cosmetic-background-night .product-copy p { color:#dedcf2; }
.product-card.cosmetic-background-night .product-price { color:#ffe39a; }
.product-card.cosmetic-background-night .product-title span { color:#62465a; background:#fff0f5e8; }
.product-preview { position:relative; height:138px; display:grid; place-items:center; overflow:hidden; border-radius:15px; }.product-preview :deep(.pet-avatar-wrap) { position:relative; z-index:1; transform:scale(.82); }.equipped-ribbon { position:absolute; z-index:4; right:2px; top:2px; padding:5px 9px; border-radius:999px; background:#667d43; color:#fff; font-size:.62rem; font-weight:750; box-shadow:0 4px 12px #34451e24; }.product-copy { flex:1; min-height:0; padding:0 5px; }.product-title { display:flex; align-items:center; justify-content:space-between; gap:8px; }.product-title h3 { color:#3d4742; font-size:.92rem; }.product-title span { padding:3px 7px; border-radius:99px; color:#8a6370; background:#f6ecef; font-size:.56rem; white-space:nowrap; }.product-copy p { margin-top:3px; color:#8a8985; font-size:.65rem; line-height:1.35; }.product-price { display:flex; align-items:baseline; gap:6px; padding:0 5px; color:#ac7b20; }.product-price span { font-size:.6rem; font-weight:750; }.product-price strong { font-size:1rem; }
.buy-button,.equip-button,.remove-button { width:calc(100% - 10px); margin:0 5px 20px; padding:9px; border-radius:10px; font-size:.73rem; font-weight:750; transition:.18s ease; }.buy-button { color:#a74f6c; background:#fff; border:1px solid #dc8ea7; }.buy-button:hover:not(:disabled) { color:#fff; background:#b95e7d; }.equip-button { color:#fff; background:#617e63; }.equip-button:hover:not(:disabled) { background:#4c694e; }.remove-button { color:#597047; background:#eef4e7; }.buy-button:disabled,.equip-button:disabled,.remove-button:disabled { opacity:.45; cursor:not-allowed; }
.orders { padding:10px 24px; border:1px solid #ebe3dc; }.orders-heading { display:flex; justify-content:space-between; align-items:center; padding:14px 0; border-bottom:1px solid #eee8e2; }.orders-heading h2 { font-size:1rem; }.orders-heading span { color:#999; font-size:.72rem; }.order-row { display:grid; grid-template-columns:48px 1fr auto; align-items:center; gap:12px; padding:14px 0; border-bottom:1px solid #f1ece8; }.order-row:last-child { border:0; }.order-preview { display:grid; place-items:center; width:46px; height:46px; overflow:hidden; border:1px solid #ebe3dc; border-radius:13px; }.order-preview :deep(.pet-avatar-wrap) { position:relative; z-index:1; }.order-row div { display:flex; flex-direction:column; }.order-row small { color:#999; font-size:.68rem; }.order-price { color:#a76b11; font-size:.8rem; font-weight:700; }.empty-orders { padding:52px 10px; text-align:center; color:#999; }.empty-orders span { display:inline-flex; padding:7px 12px; border-radius:999px; background:#f4eee8; color:#9a8273; font-size:.68rem; font-weight:750; }
@media(max-width:960px){.wardrobe{grid-template-columns:1fr 1.2fr;padding:24px 30px}.preview-meta{grid-column:1/-1;align-items:center;text-align:center}.product-grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:42px 34px}}
@media(max-width:640px){.shop-page{padding-top:18px}.shop-header{align-items:flex-start;padding-bottom:20px}.shop-header p{display:none}.shop-balance{min-width:116px;padding:9px 11px}.balance-mark{width:34px;height:34px}.wardrobe{grid-template-columns:1fr;gap:14px;min-height:auto;margin-bottom:28px;padding:22px 14px}.wardrobe-copy{text-align:center}.wardrobe h2{font-size:1.2rem}.pet-preview{width:210px;height:300px}.catalog-heading{align-items:flex-start;flex-direction:column;gap:12px}.shop-tabs{width:100%}.shop-tabs button{flex:1;padding:8px 7px}.product-grid{grid-template-columns:220px;justify-content:center;gap:48px;padding-inline:24px}.product-card{padding:20px 19px 17px;border-radius:18px}.product-preview{height:115px}.product-preview :deep(.pet-avatar-wrap){transform:scale(.72)}.product-copy p{font-size:.61rem}.product-title{align-items:flex-start;flex-direction:column;gap:3px}.buy-button,.equip-button,.remove-button{padding:6px;font-size:.66rem}.orders{padding:8px 14px}.order-row{grid-template-columns:38px 1fr auto}}
</style>
