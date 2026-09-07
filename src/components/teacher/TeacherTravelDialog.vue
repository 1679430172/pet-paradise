<template>
  <dialog ref="dialog" class="teacher-travel-dialog" aria-labelledby="teacher-travel-title" @cancel="guardClose" @close="emit('close')">
    <header><div><p class="kicker">替小伙伴安排一场远行</p><h2 id="teacher-travel-title">{{ studentName }}的宠物旅行</h2><p>{{ petName }} · 老师代为管理</p></div><button :disabled="busy" aria-label="关闭旅行弹窗" @click="dialog?.close()">×</button></header>
    <div class="balances"><span>🎫 {{ state?.tickets ?? '—' }} 张旅行券</span><span>✉ {{ state?.stamps ?? '—' }} 枚印章</span><button :disabled="busy || loading" @click="refresh">刷新</button></div>
    <p v-if="error" class="error" role="alert">{{ error }}</p>
    <p v-if="loading && !state" class="muted">正在读取学生的旅行状态…</p>
    <section v-if="reward" class="gift" role="status"><h3>🎁 已为{{ studentName }}领取行李</h3><p>{{ reward.story }}</p><p>印章 +{{ reward.stamps }}<template v-if="reward.item"> · {{ reward.item.name }}{{ reward.duplicate ? '（重复，已转印章）' : '（新装扮）' }}</template></p><small>所有奖励已进入学生的收藏。</small></section>
    <template v-if="state">
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
import { classroomRpc } from '../../lib/classroomApi'
import { useAuthStore } from '../../stores/auth'
import type { Destination, TravelReward, TravelState } from '../../stores/travel'
const props = defineProps<{ studentId: string; studentName: string; petId: string; petName: string }>()
const emit = defineEmits<{ close: []; updated: [] }>()
const auth = useAuthStore()
const dialog = ref<HTMLDialogElement | null>(null), state = ref<TravelState | null>(null)
const selectedPlace = ref<Destination | null>(null), reward = ref<TravelReward | null>(null)
const busy = ref(false), loading = ref(false), error = ref(''), now = ref(0)
let receivedAt = 0, serverAt = 0, disposed = false
const args = () => ({ p_actor_id: auth.user?.id, p_student_id: props.studentId })
const active = computed(() => (state.value?.activeTrips ?? (state.value?.active ? [state.value.active] : [])).find(t => t.pet_id === props.petId))
const currentPlace = computed(() => state.value?.destinations.find(p => p.id === active.value?.destination_id))
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
  try { await classroomRpc('teacher_start_pet_trip', { ...args(), p_pet_id: props.petId, p_destination_id: selectedPlace.value.id, p_request_id: crypto.randomUUID() }); selectedPlace.value = null; reward.value = null; await refresh(); emit('updated') }
  catch (e) { error.value = message(e) }
  finally { busy.value = false }
}
async function claim() {
  if (!active.value || !ready.value || busy.value || loading.value || error.value) return
  busy.value = true; error.value = ''
  try { reward.value = await classroomRpc<TravelReward>('teacher_claim_pet_trip', { ...args(), p_trip_id: active.value.id }); await refresh(); emit('updated') }
  catch (e) { error.value = message(e) }
  finally { busy.value = false }
}
function guardClose(event: Event) { if (busy.value) event.preventDefault() }
function onVisible() { if (document.visibilityState === 'visible' && !busy.value) void refresh() }
let timer: ReturnType<typeof setInterval>
onMounted(() => { dialog.value?.showModal(); void refresh(); timer = setInterval(() => { now.value = serverAt + performance.now() - receivedAt }, 1000); document.addEventListener('visibilitychange', onVisible) })
onUnmounted(() => { disposed = true; clearInterval(timer); document.removeEventListener('visibilitychange', onVisible) })
</script>

<style scoped>
header>button{align-self:flex-start;width:36px;height:36px;padding:0;flex-shrink:0}
.teacher-travel-dialog{position:fixed;inset:0;margin:auto;width:min(680px,calc(100% - 28px));max-height:90dvh;overflow:auto;padding:26px;border:1px solid #e1dccc;border-radius:24px;background:#fffdf6;color:#3d5347;box-shadow:0 22px 70px #24362833}.teacher-travel-dialog::backdrop{background:#263d4266;backdrop-filter:blur(3px)}header{display:flex;justify-content:space-between;gap:12px}h2{font-size:1.3rem;margin:6px 0}header p{font-size:.8rem;color:#7a8476}.kicker{font-size:.65rem!important;color:#9e8247!important;letter-spacing:.12em}button{padding:10px 15px;border-radius:11px;background:#edf0e6;color:#526547;font:inherit;font-size:.83rem;cursor:pointer}button:disabled{opacity:.5;cursor:not-allowed}button:focus-visible,a:focus-visible{outline:3px solid #a98e52;outline-offset:3px}.primary{background:#496d55;color:white}.balances{display:flex;align-items:center;flex-wrap:wrap;gap:12px;margin:22px 0;font-size:.85rem}.balances span{padding:8px 12px;border-radius:99px;background:#f3edda}.balances button{margin-left:auto}.destinations{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin:14px 0}.destinations button{display:flex;flex-direction:column;align-items:center;padding:20px 12px;background:#eef2dd;border:1px solid #d9e1c8}.destinations .coast{background:#e9f4f2;border-color:#cee2df}.destinations .stars{background:#eeebf7;border-color:#dcd5ed}.destinations strong{margin:12px 0 8px;font-size:.95rem}.destinations small{font-size:.72rem}.destinations p{font-size:.67rem;margin-top:14px;line-height:1.7}.place-icon{font-size:2.6rem}.muted{font-size:.8rem;color:#7b8576;line-height:1.8}.rules{margin-top:18px}.active-trip{text-align:center;padding:20px;background:#f1f4e8;border-radius:18px}.active-trip h3,.active-trip p{margin:12px 0}.active-trip button{margin-top:10px}.confirmation h3{margin:24px 0 16px}.confirmation dl{padding:14px;background:#f1f3e9;border-radius:14px}.confirmation dl div{display:flex;justify-content:space-between;gap:15px;padding:8px;font-size:.85rem}.confirmation dd{margin:0;text-align:right;overflow-wrap:anywhere}.confirmation .muted{margin:16px 0}.actions{display:flex;justify-content:flex-end;gap:12px}.no-tickets{padding:15px;background:#fff0d8;border-radius:12px;font-size:.83rem;line-height:1.8}.no-tickets a{display:block;margin-top:8px}.choose-title{margin-top:20px;font-size:1rem}.gift{padding:18px;background:#fff4d7;border:1px solid #efdfb1;border-radius:16px;margin-bottom:18px}.gift h3{font-size:1rem}.gift p{margin:10px 0;font-size:.85rem;line-height:1.8}.gift small{color:#90845d}.error{padding:12px;background:#fff0ef;color:#a14e53;border-radius:10px;font-size:.85rem}footer{display:flex;justify-content:flex-end;margin-top:22px}footer button{min-width:100px}@media(max-width:550px){.teacher-travel-dialog{padding:20px}.destinations{grid-template-columns:1fr}.destinations button{display:grid;grid-template-columns:48px 1fr;text-align:left;gap:4px 12px;padding:14px}.destinations .place-icon{grid-row:span 3}.destinations strong,.destinations p{margin:0}.destinations p{grid-column:2}.balances{gap:8px}.balances span{font-size:.75rem;padding:7px 9px}}
</style>
