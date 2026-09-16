<template>
  <dialog ref="dialog" class="teacher-travel-dialog" aria-labelledby="teacher-travel-title" @cancel="guardClose" @close="emit('close')">
    <header><div><p class="kicker">替小伙伴安排一场远行</p><h2 id="teacher-travel-title">{{ studentName }}的宠物旅行</h2><p>{{ petName }} · 老师代为管理</p></div><button :disabled="busy" aria-label="关闭旅行弹窗" @click="dialog?.close()">×</button></header>
    <div class="balances"><span>🎫 {{ state?.tickets ?? '—' }} 张旅行券</span><span>✉ {{ state?.stamps ?? '—' }} 枚印章</span><button :disabled="busy || loading" @click="refresh">刷新</button></div>
    <p v-if="error" class="error" role="alert">{{ error }}</p>
    <p v-if="loading && !state" class="muted">正在读取学生的旅行状态…</p>
    <section v-if="reward && claimedTrip" class="reward-letter" :class="claimedTrip.destination_id" role="status">
      <p class="letter-eyebrow">老师代收的远方来信</p>
      <h2>{{ claimedTrip.pet_name }} 给{{ studentName }}寄来了一封信</h2>
      <div v-if="!rewardOpened" class="envelope-stage">
        <button class="envelope" :class="{ opening: rewardOpening }" :disabled="rewardOpening" aria-label="打开远方来信" @click="openRewardEnvelope">
          <span class="envelope-letter" aria-hidden="true"></span><span class="envelope-back" aria-hidden="true"></span><span class="envelope-front" aria-hidden="true"></span><span class="envelope-flap" aria-hidden="true"></span>
          <span class="envelope-address" aria-hidden="true"><small>TO</small><strong>{{ studentName }}</strong><em>FROM {{ claimedTrip.pet_name }} · {{ rewardPlace?.name ?? '远方' }}</em></span>
          <span class="envelope-postage" aria-hidden="true"><b>{{ rewardPlace?.icon ?? '✉' }}</b><small>PET<br>POST</small></span><span class="envelope-seal" aria-hidden="true">🐾</span>
        </button>
        <p>{{ rewardOpening ? '正在拆开信封…' : '点一下，看看它从远方带回了什么' }}</p>
      </div>
      <Transition name="postcard-reveal">
        <div v-if="rewardOpened" class="reward-reveal">
          <p class="arrival-note">✉ 旅行明信片已收入{{ studentName }}的相册</p>
          <TravelPostcard :destination-id="claimedTrip.destination_id" :name="rewardPlace?.name ?? '远方'" :icon="rewardPlace?.icon ?? '✉'" :story="reward.story" :pet-snapshot="claimedTrip.pet_snapshot" :pet-name="claimedTrip.pet_name" source="trip" :number="rewardPostcardNumber" />
          <div class="reward-extras"><strong>行李里的其他收获</strong><p>旅行印章 +{{ reward.stamps }}</p><p v-if="reward.item">{{ reward.item.name }}{{ reward.duplicate ? '（重复，已转为印章）' : '（新装扮）' }}</p></div>
          <button class="primary collect-letter" @click="dialog?.close()">收好这张明信片</button>
        </div>
      </Transition>
    </section>
    <template v-if="state && !reward">
      <section v-if="active" class="active-trip">
        <span class="place-icon" aria-hidden="true">{{ currentPlace?.icon || '🧳' }}</span><h3>{{ active.pet_name }} · {{ currentPlace?.name }}</h3>
        <p>{{ ready ? '宠物已经回来，行李等待领取' : `旅行中 · 剩余 ${remaining}` }}</p><p class="muted">预计归来：{{ formatTime(active.returns_at) }}</p>
        <button class="primary" :disabled="busy || loading || !!error || !ready" @click="claim">{{ busy ? '正在领取…' : ready ? '代领旅行行李' : '等待宠物归来' }}</button>
      </section>
      <section v-else-if="selectedPlace" class="confirmation">
        <h3>🧳 确认前往{{ selectedPlace.name }}？</h3>
        <dl><div><dt>学生 / 宠物</dt><dd>{{ studentName }} / {{ petName }}</dd></div><div><dt>旅行时长</dt><dd>{{ selectedPlace.hours }} 小时</dd></div><div><dt>消耗旅行券</dt><dd>1 张（当前 {{ state.tickets }} 张）</dd></div></dl>
        <p class="muted">出发后无法取消，期间仍可正常喂养。本次出发会记录为老师代操作。</p>
        <div class="actions"><button :disabled="busy" @click="selectedPlace = null">再想想</button><button class="primary" :disabled="busy || loading || !!error || !state.canDepart" @click="depart">{{ busy ? '出发中…' : '确认代为出发' }}</button></div>
      </section>
      <template v-else>
        <div v-if="!state.canDepart" class="no-tickets">暂无旅行券。完成带有旅行券奖励的任务后，由老师确认发放。<RouterLink to="/teacher/students" @click="dialog?.close()">前往学生奖励 →</RouterLink></div>
        <h3 class="choose-title">为{{ petName }}选择目的地</h3>
        <div class="destinations"><button v-for="place in state.destinations" :key="place.id" :class="place.id" :disabled="busy || loading || !!error || !state.canDepart" @click="selectedPlace = place"><span class="place-icon" aria-hidden="true">{{ place.icon }}</span><strong>{{ place.name }}</strong><small>{{ place.hours }} 小时 · 1 张旅行券</small><p>{{ state.items.filter(i => i.destination_id === place.id).map(i => i.name).join(' / ') }}</p></button></div>
        <p class="muted rules">每次保底明信片和 1 枚印章；1% 概率获得当地装扮。与学生端共享旅行状态，不会重复派出。</p>
      </template>
    </template>
    <footer><button :disabled="busy" @click="dialog?.close()">完成</button></footer>
  </dialog>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import TravelPostcard from '../TravelPostcard.vue'
import { classroomRpc } from '../../lib/classroomApi'
import { useAuthStore } from '../../stores/auth'
import type { Destination, TravelReward, TravelState, Trip } from '../../stores/travel'
import { randomUuid } from '../../lib/uuid'
const props = defineProps<{ studentId: string; studentName: string; petId: string; petName: string }>()
const emit = defineEmits<{ close: []; updated: [] }>()
const auth = useAuthStore()
const dialog = ref<HTMLDialogElement | null>(null), state = ref<TravelState | null>(null)
const selectedPlace = ref<Destination | null>(null), reward = ref<TravelReward | null>(null)
const claimedTrip = ref<Trip | null>(null), rewardOpened = ref(false), rewardOpening = ref(false)
const busy = ref(false), loading = ref(false), error = ref(''), now = ref(0)
let receivedAt = 0, serverAt = 0, disposed = false
const args = () => ({ p_actor_id: auth.user?.id, p_student_id: props.studentId })
const active = computed(() => (state.value?.activeTrips ?? (state.value?.active ? [state.value.active] : [])).find(t => t.pet_id === props.petId))
const currentPlace = computed(() => state.value?.destinations.find(p => p.id === active.value?.destination_id))
const rewardPlace = computed(() => state.value?.destinations.find(p => p.id === claimedTrip.value?.destination_id))
const rewardPostcardNumber = computed(() => Math.max(0, rewardPlace.value?.stories.indexOf(reward.value?.story ?? '') ?? -1) + 1)
const ready = computed(() => !!active.value && now.value >= Date.parse(active.value.returns_at))
const remaining = computed(() => { const minutes = Math.max(1, Math.ceil((Date.parse(active.value!.returns_at) - now.value) / 60000)); return `${Math.floor(minutes / 60)} 小时 ${minutes % 60} 分钟` })
const formatTime = (value: string) => new Intl.DateTimeFormat('zh-CN', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value))
const message = (e: unknown) => e instanceof Error ? e.message.replace('课堂功能数据库迁移', '老师代旅行数据库迁移') : '操作失败，请重试'
async function refresh() {
  if (loading.value) return
  loading.value = true; error.value = ''
  try { const data = await classroomRpc<TravelState>('teacher_travel_state', args()); if (disposed) return; state.value = data; serverAt = Date.parse(data.serverNow); receivedAt = performance.now(); now.value = serverAt }
  catch (e) { error.value = message(e) }
  finally { loading.value = false }
}
async function depart() {
  if (!selectedPlace.value || busy.value || !state.value?.canDepart || loading.value || error.value) return
  busy.value = true; error.value = ''
  try { await classroomRpc('teacher_start_pet_trip', { ...args(), p_pet_id: props.petId, p_destination_id: selectedPlace.value.id, p_request_id: randomUuid() }); selectedPlace.value = null; reward.value = null; claimedTrip.value = null; await refresh(); emit('updated') }
  catch (e) { error.value = message(e) }
  finally { busy.value = false }
}
async function claim() {
  if (!active.value || !ready.value || busy.value || loading.value || error.value) return
  busy.value = true; error.value = ''
  claimedTrip.value = { ...active.value, pet_snapshot: active.value.pet_snapshot ? { ...active.value.pet_snapshot } : null }
  try { reward.value = await classroomRpc<TravelReward>('teacher_claim_pet_trip', { ...args(), p_trip_id: active.value.id }); rewardOpened.value = false; rewardOpening.value = false; await refresh(); emit('updated') }
  catch (e) { claimedTrip.value = null; error.value = message(e) }
  finally { busy.value = false }
}
let rewardTimer: ReturnType<typeof setTimeout>
function openRewardEnvelope() { if (rewardOpening.value || rewardOpened.value) return; rewardOpening.value = true; rewardTimer = setTimeout(() => { rewardOpened.value = true; rewardOpening.value = false }, 720) }
function guardClose(event: Event) { if (busy.value) event.preventDefault() }
function onVisible() { if (document.visibilityState === 'visible' && !busy.value) void refresh() }
let timer: ReturnType<typeof setInterval>
onMounted(() => { dialog.value?.showModal(); void refresh(); timer = setInterval(() => { now.value = serverAt + performance.now() - receivedAt }, 1000); document.addEventListener('visibilitychange', onVisible) })
onUnmounted(() => { disposed = true; clearInterval(timer); clearTimeout(rewardTimer); document.removeEventListener('visibilitychange', onVisible) })
</script>

<style scoped>
header>button{align-self:flex-start;width:36px;height:36px;padding:0;flex-shrink:0}
.teacher-travel-dialog{position:fixed;inset:0;margin:auto;width:min(680px,calc(100% - 28px));max-height:90dvh;overflow:auto;padding:26px;border:1px solid #e1dccc;border-radius:24px;background:#fffdf6;color:#3d5347;box-shadow:0 22px 70px #24362833}.teacher-travel-dialog::backdrop{background:#263d4266;backdrop-filter:blur(3px)}header{display:flex;justify-content:space-between;gap:12px}h2{font-size:1.3rem;margin:6px 0}header p{font-size:.8rem;color:#7a8476}.kicker{font-size:.65rem!important;color:#9e8247!important;letter-spacing:.12em}button{padding:10px 15px;border-radius:11px;background:#edf0e6;color:#526547;font:inherit;font-size:.83rem;cursor:pointer}button:disabled{opacity:.5;cursor:not-allowed}button:focus-visible,a:focus-visible{outline:3px solid #a98e52;outline-offset:3px}.primary{background:#496d55;color:white}.balances{display:flex;align-items:center;flex-wrap:wrap;gap:12px;margin:22px 0;font-size:.85rem}.balances span{padding:8px 12px;border-radius:99px;background:#f3edda}.balances button{margin-left:auto}.destinations{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin:14px 0}.destinations button{display:flex;flex-direction:column;align-items:center;padding:20px 12px;background:#eef2dd;border:1px solid #d9e1c8}.destinations .coast{background:#e9f4f2;border-color:#cee2df}.destinations .stars{background:#eeebf7;border-color:#dcd5ed}.destinations strong{margin:12px 0 8px;font-size:.95rem}.destinations small{font-size:.72rem}.destinations p{font-size:.67rem;margin-top:14px;line-height:1.7}.place-icon{font-size:2.6rem}.muted{font-size:.8rem;color:#7b8576;line-height:1.8}.rules{margin-top:18px}.active-trip{text-align:center;padding:20px;background:#f1f4e8;border-radius:18px}.active-trip h3,.active-trip p{margin:12px 0}.active-trip button{margin-top:10px}.confirmation h3{margin:24px 0 16px}.confirmation dl{padding:14px;background:#f1f3e9;border-radius:14px}.confirmation dl div{display:flex;justify-content:space-between;gap:15px;padding:8px;font-size:.85rem}.confirmation dd{margin:0;text-align:right;overflow-wrap:anywhere}.confirmation .muted{margin:16px 0}.actions{display:flex;justify-content:flex-end;gap:12px}.no-tickets{padding:15px;background:#fff0d8;border-radius:12px;font-size:.83rem;line-height:1.8}.no-tickets a{display:block;margin-top:8px}.choose-title{margin-top:20px;font-size:1rem}.gift{padding:18px;background:#fff4d7;border:1px solid #efdfb1;border-radius:16px;margin-bottom:18px}.gift h3{font-size:1rem}.gift p{margin:10px 0;font-size:.85rem;line-height:1.8}.gift small{color:#90845d}.error{padding:12px;background:#fff0ef;color:#a14e53;border-radius:10px;font-size:.85rem}footer{display:flex;justify-content:flex-end;margin-top:22px}footer button{min-width:100px}@media(max-width:550px){.teacher-travel-dialog{padding:20px}.destinations{grid-template-columns:1fr}.destinations button{display:grid;grid-template-columns:48px 1fr;text-align:left;gap:4px 12px;padding:14px}.destinations .place-icon{grid-row:span 3}.destinations strong,.destinations p{margin:0}.destinations p{grid-column:2}.balances{gap:8px}.balances span{font-size:.75rem;padding:7px 9px}}

.reward-letter{--mail-accent:#587b66;--mail-light:#dce8d9;margin:20px -6px 0;padding:24px;border:1px solid #e3dcc8;border-radius:20px;background:radial-gradient(circle at 12% 8%,#fff 0 2px,transparent 3px),#fffdf5;background-size:25px 25px;text-align:center}.reward-letter.coast{--mail-accent:#4c8791;--mail-light:#d3e8ea}.reward-letter.stars{--mail-accent:#70658d;--mail-light:#ded9ed}.letter-eyebrow{margin:0;color:var(--mail-accent);font-size:.68rem;letter-spacing:.12em}.reward-letter h2{margin:8px 0 0}.envelope-stage{display:flex;min-height:330px;flex-direction:column;align-items:center;justify-content:center}.envelope-stage>p{margin:34px 0 0;color:#777467;font-size:.8rem}.envelope{position:relative;isolation:isolate;width:min(360px,75vw);height:220px;padding:0;border:0;background:transparent;perspective:1000px;filter:drop-shadow(0 18px 15px #5d493438);transition:transform .2s ease}.envelope:before{content:"";position:absolute;z-index:-1;inset:-7px;border-radius:13px;background:repeating-linear-gradient(135deg,#c76862 0 12px,#fff9ed 12px 24px,#6f9aa5 24px 36px,#fff9ed 36px 48px)}.envelope:disabled{opacity:1}.envelope-back,.envelope-front,.envelope-flap,.envelope-letter{position:absolute;inset:0;display:block}.envelope-back{border:1px solid #d1b98d;border-radius:8px;background:linear-gradient(135deg,#fffdf5,#f1e7d1);box-shadow:inset 0 0 24px #c5a56d18}.envelope-letter{inset:18px 24px 12px;border-radius:5px;background:linear-gradient(#fffefb,#f7f0de);box-shadow:0 2px 8px #70563026;transition:transform .62s .16s ease}.envelope-front{z-index:1;clip-path:polygon(0 0,50% 60%,100% 0,100% 100%,0 100%);border:1px solid #cdb385;border-radius:8px;background:linear-gradient(152deg,#fbf2df 0,#ecdbba 56%,#e3c99c 100%)}.envelope-flap{z-index:4;clip-path:polygon(0 0,100% 0,50% 64%);border-top:1px solid #d0b788;border-radius:8px;background:linear-gradient(165deg,#fffaf0,#ead6b0);transform-origin:top;backface-visibility:hidden;transition:transform .58s cubic-bezier(.45,.05,.25,1)}.envelope-address{position:absolute;z-index:2;left:27px;bottom:24px;display:grid;grid-template-columns:auto 1fr;gap:2px 9px;text-align:left;color:#50685a;transform:rotate(-1deg)}.envelope-address small{align-self:end;color:#a26d54;font:700 .53rem/1 sans-serif;letter-spacing:.14em}.envelope-address strong{font:600 1rem/1.25 "KaiTi","STKaiti",serif}.envelope-address em{grid-column:1/-1;margin-top:8px;color:#847966;font:normal .51rem/1.3 sans-serif}.envelope-postage{position:absolute;z-index:5;right:22px;top:18px;display:grid;width:57px;height:68px;place-items:center;border:5px solid transparent;border-image:repeating-linear-gradient(45deg,var(--mail-light) 0 3px,#fff 3px 6px) 5;background:#fffdf4;color:var(--mail-accent);box-shadow:0 2px 4px #806a4322}.envelope-postage b{font-size:1.55rem;line-height:1}.envelope-postage small{font:700 .42rem/1.05 sans-serif;letter-spacing:.12em}.envelope-seal{position:absolute;z-index:6;left:50%;top:55%;display:grid;width:54px;height:54px;place-items:center;border:2px solid #d88b7f;border-radius:50%;background:radial-gradient(circle at 36% 30%,#d98578,#a9433e 68%);color:#ffe9d3;font-size:1.28rem;box-shadow:0 3px 0 #813631,0 5px 9px #70403942;transform:translate(-50%,-50%) rotate(-5deg);transition:opacity .22s .12s,transform .36s}.envelope:hover:not(:disabled){transform:translateY(-4px)}.envelope.opening .envelope-flap{z-index:0;transform:rotateX(180deg)}.envelope.opening .envelope-letter{transform:translateY(-78px)}.envelope.opening .envelope-seal{opacity:0;transform:translate(-50%,-50%) scale(.45) rotate(18deg)}.reward-reveal{max-width:520px;margin:22px auto 0}.arrival-note{display:inline-block;margin:0 0 14px;padding:7px 13px;border-radius:999px;background:#edf4e8;color:#4f7058;font-size:.75rem}.reward-reveal :deep(.postcard){box-shadow:0 18px 45px #44351e24;transform:rotate(-.35deg)}.reward-extras{margin:20px 0;padding:14px 18px;border-radius:14px;background:#f1f4e9;text-align:left}.reward-extras strong{display:block;margin-bottom:7px;font-size:.76rem;color:#6b775f}.reward-extras p{margin:4px 0;font-size:.82rem}.collect-letter{width:100%;min-height:44px}.postcard-reveal-enter-active{animation:postcard-arrive .65s cubic-bezier(.2,.75,.25,1)}@keyframes postcard-arrive{0%{opacity:0;transform:translateY(70px) scale(.86)}100%{opacity:1;transform:none}}@media(max-width:550px){.reward-letter{padding:20px 10px}.reward-letter h2{font-size:1.1rem}.envelope-stage{min-height:270px}.envelope{height:172px}.reward-reveal{margin-top:14px}}@media(prefers-reduced-motion:reduce){.envelope-flap,.envelope-letter,.envelope-seal{transition-duration:.01ms!important}.postcard-reveal-enter-active{animation:none}}
</style>
