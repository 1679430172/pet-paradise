<template>
  <main class="page travel-page">
    <header class="travel-header">
      <div><p class="eyebrow">带着好奇心出发</p><h1>宠物旅行手记</h1><p>去看看远方，把小小的惊喜带回家。</p></div>
      <div class="stamp-wallet"><span>✉</span><strong>{{ travel.state?.stamps ?? '—' }}</strong><small>旅行印章</small></div>
    </header>
    <div v-if="travel.state" class="ticket-balance"><strong>🎫 我的旅行券：{{ travel.state.tickets }} 张</strong><span>完成老师指定的任务获得 · 每次出发消耗 1 张 · 可积攒，不失效</span><button :disabled="travel.loading || travel.busy" @click="load">刷新余额</button></div>
    <p v-if="notice" class="travel-notice" role="status">{{ notice }}</p>
    <div v-if="travel.error" class="travel-error" role="alert">{{ travel.error }} <button @click="load" :disabled="travel.loading">重新加载</button></div>
    <p v-if="!travel.state && travel.loading" class="empty">正在整理旅行背包…</p>
    <template v-if="travel.state">
      <label v-if="pets.pets.length" class="travel-partner">旅行伙伴<select v-model="selectedPet"><option v-for="pet in pets.pets" :key="pet.id" :value="pet.id">{{ pet.name }} · Lv.{{ pet.level }}{{ (travel.state.activeTrips ?? []).some(t => t.pet_id === pet.id) ? ' · 旅行中 / 待领取' : '' }}</option></select></label>
      <section v-if="active" class="journey" :class="active.destination_id">
        <div class="journey-art" aria-hidden="true">{{ destination(active.destination_id)?.icon }}<span>··· 🧳 ···</span></div>
        <div><p class="eyebrow">{{ ready ? '远方来信' : '旅途进行中' }}</p><h2>{{ active.pet_name }}{{ ready ? '回来啦！' : '正在' + destination(active.destination_id)?.name }}</h2>
          <p>{{ ready ? '行李里装着故事，也许还有一份特别的礼物。' : '还需 ' + remaining + ' · 离开页面也会继续旅行' }}</p>
          <progress :value="progress" max="100" aria-label="旅行进度"></progress>
          <p class="muted">预计归来：{{ formatTime(active.returns_at) }} · 喂养和老师加分照常进行</p>
          <button class="primary" :disabled="!ready || disabled" @click="claim">{{ travel.busy ? '正在整理行李…' : ready ? '打开旅行行李' : '正在收集沿途的风景' }}</button>
        </div>
      </section>
      <section v-else class="departure-note">
        <span aria-hidden="true">🧳</span><div><h2>{{ travel.state.canDepart ? '这次，想去哪里？' : '攒一张券，去看看远方' }}</h2><p>{{ travel.state.canDepart ? '使用 1 张旅行券出发，每次都有明信片和印章。' : '完成带有旅行券奖励的任务，由老师确认后即可获得。' }}</p></div>
        <RouterLink v-if="!pets.pets.length" to="/pet/create">先领养一只宠物 →</RouterLink>
      </section>

      <div class="section-heading"><h2>三站远方</h2><span>每站都有专属装扮</span></div>
      <section class="destination-grid">
        <article v-for="place in travel.state.destinations" :key="place.id" class="destination-card" :class="place.id">
          <div class="landscape" aria-hidden="true"><span>{{ place.icon }}</span><i>{{ place.id === 'forest' ? '🌿' : place.id === 'coast' ? '🌊' : '✨' }}</i></div>
          <div class="destination-copy"><small>{{ place.hours }} 小时的慢旅行</small><h3>{{ place.name }}</h3><p>{{ place.description }}</p><div class="reward-tags"><span v-for="item in travel.state.items.filter(i => i.destination_id === place.id)" :key="item.id">{{ item.icon }} {{ item.name }}</span></div>
            <button class="primary" :disabled="disabled || !!active || !travel.state.canDepart || !selectedPet" @click="requestDeparture(place)">{{ active ? '这只宠物旅行中 / 待领取' : !travel.state.canDepart ? '暂无旅行券' : '使用 1 张旅行券出发 →' }}</button>
          </div>
        </article>
      </section>
      <details class="travel-rules"><summary>旅行与奖励规则</summary><p>完成老师指定的任务获得旅行券，每次出发消耗 1 张，不扣积分。旅行券可积攒、不失效，没有每日出发次数限制；不同宠物可以同时旅行，每只宠物只能有一段未领取的旅行，领取行李后有券就能再次出发。奖励可随时领取，不会过期。</p><p>每次保底一张随机明信片和 1 枚印章。另有 1% 概率带回当地装扮（两款各 0.5%）；重复装扮额外转成 2 枚印章。每件专属装扮可用 8 枚印章兑换。</p></details>

      <div class="section-heading"><div><p class="eyebrow">把远方穿在身上</p><h2>旅行装扮收藏</h2></div><RouterLink to="/shop">前往装扮屋 →</RouterLink></div>
      <section class="souvenir-grid">
        <article v-for="item in travel.state.items" :key="item.id" class="souvenir">
          <div class="souvenir-preview cosmetic-card" :class="cosmeticClasses({ [item.category]: item.style_key })"><span>{{ item.icon }}</span></div>
          <div><small>{{ destination(item.destination_id)?.name }} · {{ item.category === 'frame' ? '边框' : '背景' }}</small><h3>{{ item.name }}</h3><p>{{ item.owned ? '已收入收藏，可在装扮屋装备' : item.stamp_cost + ' 枚旅行印章' }}</p></div>
          <RouterLink v-if="item.owned" to="/shop">去装备 →</RouterLink><button v-else :disabled="disabled || travel.state.stamps < item.stamp_cost" @click="redeem(item)">兑换</button>
        </article>
      </section>

      <div class="section-heading"><div><p class="eyebrow">写给最想念的你</p><h2>明信片相册</h2></div><span>{{ travel.state.postcards.length }} / {{ postcardTotal }} 张</span></div>
      <p v-if="!travel.state.postcards.length" class="empty">第一封远方来信，正在等你出发。</p>
      <section class="postcard-grid"><article v-for="card in travel.state.postcards" :key="card.destination_id + card.story" class="postcard" :class="card.destination_id"><div><span>{{ destination(card.destination_id)?.name }}</span><b aria-hidden="true">{{ destination(card.destination_id)?.icon }}</b></div><p>{{ card.story }}</p><small>寄给你 · 来自远方的宠物</small></article></section>
      <details v-if="travel.state.history.length" class="travel-rules"><summary>最近 {{ travel.state.history.length }} 次旅行记录</summary><article v-for="trip in travel.state.history" :key="trip.id" class="history-entry"><strong>{{ trip.pet_name }} · {{ destination(trip.destination_id)?.name }}</strong><small>{{ formatTime(trip.started_at) }}</small><p>{{ trip.reward?.story }}</p><span>印章 +{{ trip.reward?.stamps }}{{ trip.reward?.item ? ' · ' + trip.reward.item.name + (trip.reward.duplicate ? '（重复，已转印章）' : '（新装扮）') : '' }}</span></article></details>
    </template>
    <dialog ref="departureDialog" class="reward-dialog departure-dialog" aria-labelledby="departure-title" aria-describedby="departure-hint" :aria-busy="departing" @cancel="guardDepartureClose" @close="pendingDeparture = null">
      <template v-if="pendingDeparture">
        <span class="gift" aria-hidden="true">🧳</span>
        <h2 id="departure-title">出发去{{ pendingDeparture.place.name }}？</h2>
        <dl class="departure-summary">
          <div><dt>旅行伙伴</dt><dd>{{ pendingDeparture.petName }}</dd></div>
          <div><dt>旅行时长</dt><dd>{{ pendingDeparture.place.hours }} 小时</dd></div>
          <div><dt>本次消耗</dt><dd>1 张旅行券</dd></div>
          <div><dt>当前持有</dt><dd>{{ travel.state?.tickets ?? 0 }} 张旅行券</dd></div>
        </dl>
        <p id="departure-hint">出发后无法取消，期间仍可正常喂养。</p>
        <p v-if="departureError" class="departure-error" role="alert">{{ departureError }}</p>
        <div class="departure-actions">
          <button autofocus :disabled="departing" @click="departureDialog?.close()">再想想</button>
          <button class="primary" :disabled="departing || disabled || !travel.state?.canDepart" @click="confirmDeparture">{{ departing ? '出发中…' : '确认出发' }}</button>
        </div>
      </template>
    </dialog>
    <dialog ref="rewardDialog" class="reward-dialog" aria-labelledby="travel-reward-title" @click="closeOutside">
      <template v-if="reward"><span class="gift" aria-hidden="true">🎁</span><p class="eyebrow">行李已送达</p><h2 id="travel-reward-title">这是我带给你的礼物</h2><p class="reward-story">{{ reward.story }}</p><p>✉ 旅行印章 +{{ reward.stamps }}</p><p v-if="reward.item">{{ reward.item.icon }} {{ reward.item.name }}{{ reward.duplicate ? ' · 重复装扮已转为 2 枚印章（计入上方总数）' : ' · 新装扮已收藏！' }}</p><div><RouterLink v-if="reward.item && !reward.duplicate" to="/shop">去装备 →</RouterLink><button class="primary" @click="rewardDialog?.close()">收好这份回忆</button></div></template>
    </dialog>
  </main>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref } from 'vue'
import { useTravelStore, type Destination, type TravelItem, type TravelReward } from '../stores/travel'
import { usePetStore } from '../stores/pet'
import { cosmeticClasses } from '../lib/cosmetics'
const travel = useTravelStore(), pets = usePetStore()
const selectedPet = ref(''), notice = ref(''), now = ref(0)
const reward = ref<TravelReward | null>(null), rewardDialog = ref<HTMLDialogElement | null>(null)
const departureDialog = ref<HTMLDialogElement | null>(null)
const pendingDeparture = ref<{ place: Destination; petId: string; petName: string } | null>(null)
const departing = ref(false), departureError = ref('')
const disabled = computed(() => travel.busy || travel.loading || !!travel.error)
const destination = (id: string) => travel.state?.destinations.find(d => d.id === id)
const active = computed(() => (travel.state?.activeTrips ?? (travel.state?.active ? [travel.state.active] : [])).find(t => t.pet_id === selectedPet.value))
const ready = computed(() => !!active.value && now.value >= Date.parse(active.value!.returns_at))
const remaining = computed(() => { const minutes = Math.max(1, Math.ceil((Date.parse(active.value!.returns_at) - now.value) / 60000)); return `${Math.floor(minutes / 60)} 小时 ${minutes % 60} 分钟` })
const progress = computed(() => { const t = active.value; return t ? Math.max(0, Math.min(100, (now.value - Date.parse(t.started_at)) / (Date.parse(t.returns_at) - Date.parse(t.started_at)) * 100)) : 0 })
const postcardTotal = computed(() => travel.state?.destinations.reduce((n, d) => n + d.stories.length, 0) || 0)
const formatTime = (value: string) => new Intl.DateTimeFormat('zh-CN', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value))
const showError = (e: unknown) => { notice.value = e instanceof Error ? e.message : '操作失败，请重试' }
async function load() { await travel.refresh().catch(() => undefined); now.value = travel.serverTime() }
async function requestDeparture(place: Destination) {
  const pet = pets.pets.find(p => p.id === selectedPet.value)
  if (!pet || active.value || disabled.value || !travel.state?.canDepart || pendingDeparture.value) return
  pendingDeparture.value = { place, petId: pet.id, petName: pet.name }
  departureError.value = ''
  await nextTick()
  departureDialog.value?.showModal()
}
function guardDepartureClose(event: Event) { if (departing.value) event.preventDefault() }
async function confirmDeparture() {
  const pending = pendingDeparture.value
  if (!pending || departing.value || disabled.value || !travel.state?.canDepart) return
  departing.value = true
  departureError.value = ''; notice.value = ''
  try {
    await travel.start(pending.petId, pending.place.id)
    now.value = travel.serverTime()
    notice.value = `已经出发去${pending.place.name}，祝旅途愉快！`
    departureDialog.value?.close()
  } catch (e) { departureError.value = e instanceof Error ? e.message : '出发失败，请重试' }
  finally { departing.value = false }
}
async function claim() { if (!active.value) return; notice.value = ''; try { reward.value = await travel.claim(active.value.id); rewardDialog.value?.showModal() } catch (e) { showError(e) } }
async function redeem(item: TravelItem) { notice.value = ''; try { const result = await travel.redeem(item.id); notice.value = result.alreadyOwned ? '已经拥有这件装扮啦' : `已兑换「${item.name}」，快去装扮屋试试吧！` } catch (e) { showError(e) } }
function closeOutside(event: MouseEvent) { const dialog = rewardDialog.value; if (!dialog || event.target !== dialog) return; const r = dialog.getBoundingClientRect(); if (event.clientX < r.left || event.clientX > r.right || event.clientY < r.top || event.clientY > r.bottom) dialog.close() }
let timer: ReturnType<typeof setInterval> | undefined
function onVisible() { if (document.visibilityState === 'visible' && !travel.busy && !travel.loading) void load() }
onMounted(async () => {
  timer = setInterval(() => { now.value = travel.serverTime() }, 1000)
  document.addEventListener('visibilitychange', onVisible)
  await Promise.all([load(), pets.fetchPets()]); selectedPet.value = pets.currentPet?.id || ''
})
onUnmounted(() => { clearInterval(timer); document.removeEventListener('visibilitychange', onVisible) })
</script>

<style scoped>
.travel-partner { display:flex;align-items:center;gap:12px;margin:18px 0;color:#526547; }.travel-partner select { padding:9px 12px;border:1px solid #d9e1d0;border-radius:10px;background:white;max-width:75%; }
.departure-summary{margin:20px 0;padding:16px;background:#f2f3e7;border-radius:14px;text-align:left}.departure-summary>div{display:flex;justify-content:space-between;gap:20px;padding:7px 0;font-size:.9rem}.departure-summary dt{color:#74806b;flex-shrink:0}.departure-summary dd{margin:0;text-align:right;overflow-wrap:anywhere}.departure-dialog .departure-error{color:#a13f49}.departure-actions{display:flex;justify-content:center;gap:12px}.departure-actions button{flex:1;min-height:44px}
.ticket-balance{display:flex;align-items:center;flex-wrap:wrap;gap:10px 20px;margin-bottom:20px;padding:18px 22px;background:#edf3e8;border:1px solid #d8e3cb;border-radius:16px}.ticket-balance strong{color:#426c57}.ticket-balance span{font-size:.8rem;color:#6c7d65}.ticket-balance button{margin-left:auto}
.travel-page{max-width:1140px;color:#314b44;padding-top:30px}.travel-header{display:flex;justify-content:space-between;align-items:center;gap:20px;margin-bottom:28px}.travel-header h1{font-size:clamp(1.8rem,4vw,2.65rem);margin:6px 0}.travel-header p{color:#72837c}.travel-header a{font-size:.8rem}.eyebrow{font-size:.72rem;color:#887649!important;letter-spacing:.14em;margin-top:18px}.stamp-wallet{display:grid;grid-template-columns:auto auto;gap:0 12px;padding:18px 22px;background:#fff3d7;border:1px solid #e8d4a1;border-radius:20px}.stamp-wallet>span{grid-row:span 2;font-size:2rem}.stamp-wallet strong{font-size:1.7rem}.stamp-wallet small{white-space:nowrap}.travel-page button{cursor:pointer;border-radius:12px;padding:10px 16px;background:#e9efe6;color:#37533f;font:inherit;font-size:.85rem}.travel-page button:disabled{opacity:.5;cursor:not-allowed}.travel-page button:focus-visible,.travel-page a:focus-visible,.travel-page summary:focus-visible{outline:3px solid #b07836;outline-offset:4px}.travel-page .primary{background:#426c57;color:white;min-height:44px}.travel-notice,.travel-error{padding:16px;background:#fff6dc;border-radius:12px;margin-bottom:18px}.travel-error{background:#ffeded;color:#9b3948}.departure-note{display:flex;align-items:center;gap:20px;padding:24px;background:#f0f3e9;border-radius:20px}.departure-note>span{font-size:2.7rem}.departure-note h2,.journey h2{font-size:1.3rem}.departure-note p,.journey p{font-size:.85rem;margin-top:7px;line-height:1.7}.departure-note label{margin-left:auto;font-size:.75rem;min-width:160px}.departure-note select{display:block;width:100%;margin-top:6px;border:1px solid #ccd7c8;border-radius:9px;padding:9px;background:white;font:inherit}.section-heading{display:flex;justify-content:space-between;align-items:end;gap:14px;margin:32px 0 18px}.section-heading h2{font-size:1.3rem}.section-heading span,.section-heading>a{font-size:.8rem;color:#637c6c}.destination-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:20px}.destination-card{overflow:hidden;border-radius:22px;border:1px solid #e1e7db;background:#fffdf7}.landscape{height:164px;position:relative;display:grid;place-items:center;isolation:isolate;background:radial-gradient(ellipse at 25% 10%,#fff8c9 0,transparent 48%),linear-gradient(155deg,#d8e8b8,#75a585)}.landscape:after{content:'';position:absolute;inset:65% -20% -60%;border-radius:50%;background:#ffffff35;transform:rotate(-12deg);z-index:-1}.landscape>span{font-size:5rem;filter:drop-shadow(0 10px 8px #263b2920)}.landscape i{position:absolute;font-style:normal;font-size:2rem;right:22px;bottom:22px}.coast .landscape{background:linear-gradient(165deg,#d5f3f5,#83cbd6 65%,#f2deb3 66%)}.stars .landscape{background:radial-gradient(circle at 25% 25%,#d3c5f6 1%,transparent 3%),linear-gradient(155deg,#364666,#8b8bbb)}.destination-copy{padding:20px}.destination-copy small{color:#85774f}.destination-copy h3{margin:8px 0;font-size:1.2rem}.destination-copy>p{font-size:.85rem;min-height:44px;color:#748077;line-height:1.7}.reward-tags{display:flex;flex-wrap:wrap;gap:6px;margin:16px 0}.reward-tags span{font-size:.65rem;background:#f0eee3;border-radius:6px;padding:5px 7px}.destination-copy button{width:100%}.travel-rules{padding:18px 20px;background:#f5f4ee;border-radius:14px;margin:20px 0;color:#67756b;font-size:.85rem}.travel-rules summary{cursor:pointer;font-weight:650}.travel-rules p{line-height:1.85;margin-top:10px}.souvenir-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.souvenir{display:flex;align-items:center;gap:16px;border:1px solid #e4e7dd;border-radius:16px;padding:18px;background:#fffefa}.souvenir-preview{width:66px;height:78px;flex-shrink:0;display:grid;place-items:center;border-radius:12px;background:#f4f4e9}.souvenir-preview span{font-size:1.8rem}.souvenir h3{font-size:.95rem;margin:5px 0}.souvenir small,.souvenir p{font-size:.68rem;color:#7b8276}.souvenir button,.souvenir>a{margin-left:auto;flex-shrink:0;font-size:.75rem}.postcard-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}.postcard{padding:22px;border:1px solid #d8e1c9;background:#f4f6e8;border-radius:4px 18px 4px 18px}.postcard.coast{background:#edf6f6;border-color:#c9e0e2}.postcard.stars{background:#f0edf7;border-color:#dcd4eb}.postcard>div{display:flex;align-items:center;justify-content:space-between;font-size:.75rem}.postcard b{padding:8px;border:2px dotted #b8c3ae;font-size:1.5rem}.postcard p{font-size:.9rem;line-height:1.95;margin:22px 0}.postcard small{color:#869083;font-size:.65rem}.empty{padding:40px 20px;text-align:center;color:#85917f;background:#f7f7f0;border-radius:18px}.journey{display:grid;grid-template-columns:200px 1fr;gap:24px;padding:24px;border:1px solid #d7e2cf;border-radius:22px;background:#f1f5e9}.journey-art{display:grid;place-content:center;text-align:center;font-size:5rem}.journey-art span{font-size:1.5rem}.journey progress{width:100%;height:9px;margin-top:18px;accent-color:#658868}.journey .muted{font-size:.75rem;color:#7c8675;margin-bottom:16px}.history-entry{padding:15px 0;border-top:1px solid #ddd;margin-top:12px}.history-entry small{display:block;margin-top:5px}.reward-dialog{position:fixed;inset:0;margin:auto;width:min(480px,calc(100% - 32px));max-height:85dvh;overflow:auto;padding:30px;border:1px solid #ddd5bd;border-radius:24px;text-align:center;color:#3e5847;background:#fffdf3;box-shadow:0 22px 90px #203c2733}.reward-dialog::backdrop{background:#233b4266;backdrop-filter:blur(4px)}.reward-dialog h2{font-size:1.4rem;margin:12px 0}.reward-dialog p{line-height:1.8;margin-bottom:15px}.gift{font-size:3rem}.reward-story{padding:20px;background:#f2f3e7;border-radius:12px}.reward-dialog>div{display:flex;align-items:center;justify-content:center;gap:20px;margin-top:20px}
@media(max-width:900px){.destination-grid{gap:12px}.destination-copy{padding:16px}.souvenir-grid{grid-template-columns:1fr}.postcard-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.departure-note{flex-wrap:wrap}.departure-note label{margin-left:0}.journey{grid-template-columns:120px 1fr}}
@media(max-width:600px){.travel-page{padding-top:18px}.travel-header{align-items:flex-start}.travel-header>div:first-child{min-width:0}.travel-header p{font-size:.8rem}.stamp-wallet{padding:12px;gap:0 6px}.stamp-wallet>span{font-size:1.3rem}.stamp-wallet strong{font-size:1.3rem}.stamp-wallet small{font-size:.65rem}.destination-grid,.postcard-grid{grid-template-columns:1fr}.landscape{height:150px}.departure-note{padding:18px;gap:12px}.departure-note>span{display:none}.departure-note label{width:100%}.journey{grid-template-columns:1fr;gap:4px;padding:20px}.journey-art{font-size:3rem}.journey-art span{display:none}.souvenir{padding:14px;gap:12px}.souvenir-preview{width:48px;height:60px}.section-heading{align-items:center}.section-heading h2{font-size:1.15rem}.section-heading>a{font-size:.72rem}}
</style>
