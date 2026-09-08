<template>
  <main class="page checkins-page">
    <header class="checkins-heading">
      <div><p class="eyebrow">把每一天的小进步，记录下来</p><h1>{{ teacher ? '学生打卡' : '自主打卡' }}</h1></div>
      <router-link :to="teacher ? '/teacher' : '/'" class="back-link">返回{{ teacher ? '总览' : '首页' }}</router-link>
    </header>
    <p v-if="error" class="notice error" role="alert">{{ error }}</p>
    <p v-if="message" class="notice success" role="status">{{ message }}</p>
    <div>
      <section v-if="!teacher" class="card upload-card">
        <div class="section-heading"><div><h2>今天，我做到了</h2><p>每张照片是一条独立打卡，等待老师给予鼓励。</p></div><strong class="quota">今日 {{ todayCount }}/3</strong></div>
        <p class="retention">每天最多 3 张，按北京时间计算。审核结束后照片保留 7 天；待审核最多保留 15 天。积分和文字记录继续保留。</p>
        <label class="upload-picker" :class="{ disabled: busy || !loaded || todayCount >= 3 }">
          <img v-if="preview" :src="preview" alt="待提交照片预览" />
          <span v-else class="hero-icon" aria-hidden="true">＋</span>
          <span>{{ todayCount >= 3 ? '今日已完成三次上传' : preview ? '更换照片' : '拍照或从相册选择一张照片' }}</span>
          <input ref="fileInput" type="file" accept="image/jpeg,image/png,image/webp" aria-label="选择一张打卡照片" :disabled="busy || !loaded || todayCount >= 3" @change="choosePhoto" />
        </label>
        <label for="checkin-description">说说你完成了什么（选填）</label>
        <textarea id="checkin-description" v-model="description" maxlength="200" rows="2" placeholder="例如：今天独立整理了书桌，还读了二十分钟书。" :disabled="busy || attempted" />
        <div class="upload-footer"><small>{{ photo ? `已压缩至 ${Math.ceil(photo.size / 1024)} KB` : '照片会自动压缩后上传' }} · {{ description.length }}/200</small><button class="btn btn-primary" :disabled="busy || !loaded || !photo || todayCount >= 3" @click="submit">{{ busy ? '处理中…' : attempted ? '重试本次提交' : '提交打卡' }}</button></div>
      </section>
      <p v-if="teacher && urgentCount" class="notice warning">有 {{ urgentCount }} 条待审核照片将在 2 天内过期，请及时查看。</p>
      <section class="records-section">
        <div class="section-heading"><h2>{{ teacher ? '班级照片记录' : '我的打卡记录' }}</h2><button class="text-button" :disabled="busy || loading" @click="refresh">刷新记录</button></div>
        <div class="filters">
          <label>审核状态<select v-model="status" :disabled="busy" @change="changeFilter"><option value="">全部状态</option><option value="pending">待审核</option><option value="awarded">已奖励</option><option value="rejected">不予奖励</option><option value="expired">已过期</option></select></label>
          <label v-if="teacher">学生<select v-model="studentId" :disabled="busy" @change="changeFilter"><option value="">全部学生</option><option v-for="s in students" :key="s.id" :value="s.id">{{ s.username }}</option></select></label>
          <label>提交日期<input v-model="day" type="date" :disabled="busy" @change="changeFilter" /></label>
        </div>
        <div v-if="loading" class="empty-state" role="status">正在加载照片记录…</div>
        <div v-else-if="!loaded" class="empty-state">记录加载失败，请点击“刷新记录”重试。</div>
        <div v-else-if="!entries.length" class="empty-state">{{ status === 'pending' && teacher ? '目前没有待审核的打卡' : '还没有符合条件的打卡记录' }}</div>
        <div v-else class="checkin-grid">
          <article v-for="entry in entries" :key="entry.id" class="card checkin-card">
            <button class="photo-button" :aria-label="`查看${entry.student_name}的打卡详情`" @click="openEntry(entry)">
              <img v-if="entry.image_url" :src="entry.image_url" :alt="`${entry.student_name}的打卡照片`" loading="lazy" @error="entry.image_url = null; entry.image_error = true" />
              <span v-else>{{ unavailablePhoto(entry) }}</span>
            </button>
            <div class="checkin-content"><div class="section-heading"><strong>{{ teacher ? entry.student_name : '我的打卡' }}</strong><span class="status-pill" :class="entry.revoked ? 'rejected' : entry.status">{{ label(entry) }}</span></div>
              <p class="description">{{ entry.description || '记录今天的一份努力' }}</p>
              <small>{{ formatDate(entry.submitted_at) }}</small>
              <p v-if="entry.feedback" class="feedback">老师说：{{ entry.feedback }}</p>
              <button class="text-button detail-button" @click="openEntry(entry)">{{ teacher && entry.status === 'pending' ? '查看并审核 →' : '查看详情 →' }}</button>
            </div>
          </article>
        </div>
        <nav class="checkin-pagination" aria-label="打卡记录分页"><button :disabled="loading || busy || page <= 1" @click="changePage(-1)">上一页</button><span>第 {{ page }} / {{ pages }} 页 · {{ total }} 条</span><button :disabled="loading || busy || page >= pages" @click="changePage(1)">下一页</button></nav>
      </section>
    </div>
    <dialog ref="dialog" class="checkin-dialog" @close="selected = null" @cancel="busy && $event.preventDefault()">
      <template v-if="selected">
        <header class="section-heading"><h2>{{ selected.student_name }}的打卡</h2><button autofocus class="text-button" :disabled="busy" @click="dialog?.close()">关闭</button></header>
        <button v-if="selected.image_url" class="detail-photo-trigger" aria-label="全屏放大照片" @click="photoViewer?.open(selected.image_url)">
          <img class="detail-photo" :src="selected.image_url" alt="打卡照片大图" @error="selected.image_url = null; selected.image_error = true" />
          <span>🔍 点击查看大图</span>
        </button>
        <p v-else class="empty-state">{{ unavailablePhoto(selected) }}</p>
        <p class="description">{{ selected.description || '未填写说明' }}</p><small>{{ formatDate(selected.submitted_at) }} · {{ label(selected) }}</small>
        <p v-if="selected.feedback" class="feedback">老师说：{{ selected.feedback }}</p>
        <p v-if="error" class="notice error" role="alert">{{ error }}</p>
        <form v-if="teacher && selected.status === 'pending'" class="review-form" @submit.prevent="review(false)">
          <label for="reward-points">奖励积分</label><input id="reward-points" v-model="reward" type="number" min="1" max="10000" step="1" required :disabled="busy" placeholder="请输入积分" />
          <label for="review-feedback">给学生的反馈（选填）</label><textarea id="review-feedback" v-model="feedback" maxlength="200" rows="2" :disabled="busy" />
          <div class="review-actions"><button type="button" class="btn" :disabled="busy" @click="review(true)">不给积分</button><button class="btn btn-primary" :disabled="busy">{{ busy ? '保存中…' : '确认发放积分' }}</button></div>
        </form>
      </template>
    </dialog>
    <PhotoViewer ref="photoViewer" />
  </main>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, onBeforeUnmount, ref } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useRouter } from 'vue-router'
import PhotoViewer from '../components/common/PhotoViewer.vue'
import { checkinApi, compressCheckinPhoto, photoBase64, checkinToken, sessionErrorKey, type PhotoCheckin, type CheckinList } from '../lib/photoCheckins'
const auth = useAuthStore()
const router = useRouter()
const teacher = computed(() => auth.isTeacher)
const actorId = auth.user!.id
const error = ref(''), message = ref(''), busy = ref(false), loading = ref(false), loaded = ref(false)
const entries = ref<PhotoCheckin[]>([]), students = ref<CheckinList['students']>([])
const todayCount = ref(0), urgentCount = ref(0), total = ref(0), page = ref(1)
const status = ref(teacher.value ? 'pending' : ''), studentId = ref(''), day = ref('')
const pages = computed(() => Math.max(1, Math.ceil(total.value / 12)))
const photo = ref<Blob | null>(null), preview = ref(''), description = ref(''), requestId = ref(''), attempted = ref(false)
const fileInput = ref<HTMLInputElement>(), dialog = ref<HTMLDialogElement>(), selected = ref<PhotoCheckin | null>(null)
const photoViewer = ref<InstanceType<typeof PhotoViewer>>()
const reward = ref<number | string>(''), feedback = ref('')
let generation = 0
function fail(e: unknown) {
  error.value = e instanceof Error ? e.message : '操作失败，请重试'
  if (!checkinToken(actorId) && !localStorage.getItem(sessionErrorKey(actorId))) void relogin()
}
async function relogin() {
  dialog.value?.close()
  const redirect = teacher.value ? '/teacher/checkins' : '/checkins'
  await auth.signOut()
  await router.replace({ path: '/login', query: { redirect, reason: 'session' } })
}
async function refresh() {
  if (!checkinToken(actorId)) {
    const unavailable = localStorage.getItem(sessionErrorKey(actorId))
    if (unavailable) { error.value = unavailable; loaded.value = false; return }
    await relogin(); return
  }
  const current = ++generation; loading.value = true; error.value = ''
  try {
    const data = await checkinApi<CheckinList>(actorId, 'list', { page: page.value, status: status.value, studentId: studentId.value, day: day.value })
    if (current !== generation) return
    entries.value = data.entries; total.value = data.total; todayCount.value = data.todayCount
    urgentCount.value = data.urgentCount; students.value = data.students; loaded.value = true
    if (page.value > pages.value) { page.value = pages.value; await refresh() }
  } catch (e) { if (current === generation) { loaded.value = false; entries.value = []; fail(e) } }
  finally { if (current === generation) loading.value = false }
}
function changeFilter() { page.value = 1; void refresh() }
function changePage(delta: number) { page.value += delta; void refresh() }
async function choosePhoto(event: Event) {
  const file = (event.target as HTMLInputElement).files?.[0]
  if (!file) return
  busy.value = true; error.value = ''; message.value = ''
  try {
    const result = await compressCheckinPhoto(file)
    if (preview.value) URL.revokeObjectURL(preview.value)
    photo.value = result; preview.value = URL.createObjectURL(result); requestId.value = crypto.randomUUID(); attempted.value = false
  } catch (e) { fail(e) } finally { busy.value = false; if (fileInput.value) fileInput.value.value = '' }
}
async function submit() {
  if (!photo.value || busy.value) return
  busy.value = true; error.value = ''; message.value = ''; attempted.value = true
  try {
    await checkinApi(actorId, 'upload', { id: requestId.value, description: description.value.trim(), image: await photoBase64(photo.value) })
    URL.revokeObjectURL(preview.value); preview.value = ''; photo.value = null; description.value = ''; attempted.value = false
    message.value = '打卡已提交，等待老师审核。'; page.value = 1; status.value = ''; day.value = ''
    await refresh()
  } catch (e) { fail(e) } finally { busy.value = false }
}
async function openEntry(entry: PhotoCheckin) {
  selected.value = entry; reward.value = ''; feedback.value = ''; error.value = ''
  await nextTick(); dialog.value?.showModal()
}
async function review(noPoints: boolean) {
  if (!selected.value || busy.value) return
  const points = noPoints ? 0 : Number(reward.value)
  if (!Number.isInteger(points) || (!noPoints && points < 1) || points > 10000) { error.value = '请输入 1 至 10000 的整数积分'; return }
  busy.value = true; error.value = ''; message.value = ''
  try {
    await checkinApi(actorId, 'review', { id: selected.value.id, points, feedback: feedback.value.trim() })
    dialog.value?.close(); message.value = points ? `已发放 ${points} 积分。` : '已审核，本次不发放积分。'
    await refresh()
  } catch (e) { fail(e) } finally { busy.value = false }
}
function label(entry: PhotoCheckin) { return entry.revoked ? '奖励已撤销' : ({ pending: '待审核', awarded: `已奖励 +${entry.points}`, rejected: '不予奖励', expired: '已过期' })[entry.status] }
function unavailablePhoto(entry: PhotoCheckin) { return entry.image_error ? '照片加载失败，请关闭详情并刷新重试' : entry.photo_deleted_at ? '照片已到期清理' : '照片已到期，不再展示' }
function formatDate(value: string) { return new Date(value).toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false }) }
onMounted(() => { void refresh() })
onBeforeUnmount(() => { generation++; if (preview.value) URL.revokeObjectURL(preview.value) })
</script>

<style scoped>
.checkins-page { max-width: 1080px; margin: 0 auto; }
.detail-photo-trigger { display:block; width:100%; border:0; background:none; padding:0; cursor:zoom-in; text-align:center; color:#9a542c; }.detail-photo-trigger span { display:block; font-size:.85rem; margin:-6px 0 12px; }
.checkins-heading,.section-heading,.upload-footer,.review-actions,.checkin-pagination { display:flex; align-items:center; justify-content:space-between; gap:12px; }
.checkins-heading { margin-bottom:24px; }.checkins-heading h1 { font-size:1.7rem; margin:4px 0; }.eyebrow { color:#84736b; font-size:.85rem; }
.back-link,.text-button { color:#9a542c; font-size:.9rem; text-decoration:none; }.text-button { border:0; background:none; cursor:pointer; padding:8px 0; }
.unlock-card { max-width:440px; margin:40px auto; padding:28px; display:grid; gap:14px; }.unlock-card p,.retention,.section-heading p { color:#756b65; line-height:1.7; font-size:.88rem; }.hero-icon { font-size:2.5rem; }
input,textarea,select { width:100%; border:1px solid #d8cdc2; border-radius:12px; padding:11px; background:#fff; color:#3f352e; font:inherit; box-sizing:border-box; }textarea { resize:vertical; }label { display:block; font-size:.9rem; }button:disabled { opacity:.5; cursor:not-allowed; }input:focus-visible,textarea:focus-visible,select:focus-visible,button:focus-visible,a:focus-visible { outline:3px solid #e8aa68; outline-offset:3px; }
.upload-card { padding:24px; margin-bottom:30px; }.section-heading h2 { font-size:1.15rem; margin:0; }.section-heading p { margin:6px 0; }.quota { white-space:nowrap; background:#fff1d9; color:#98641d; border-radius:20px; padding:9px 14px; }.retention { margin:14px 0; }
.upload-picker { position:relative; overflow:hidden; min-height:150px; border:2px dashed #dbc8ad; background:#fffcf7; border-radius:16px; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:8px; margin-bottom:18px; cursor:pointer; padding:16px; }.upload-picker img { max-height:220px; max-width:100%; border-radius:10px; }.upload-picker input { position:absolute; inset:0; opacity:0; cursor:pointer; }.upload-picker:focus-within { outline:3px solid #e8aa68; }.upload-picker.disabled { opacity:.6; cursor:not-allowed; }.upload-footer { margin-top:12px; }.upload-footer small,small { color:#80736b; }.upload-card textarea { margin-top:8px; }
.filters { display:flex; gap:12px; flex-wrap:wrap; margin:16px 0; }.filters label { flex:1; min-width:145px; }.filters select,.filters input { margin-top:6px; }.checkin-grid { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:18px; }.checkin-card { overflow:hidden; padding:0; }.photo-button { border:0; background:#f4ede4; width:100%; aspect-ratio:4/3; padding:0; cursor:pointer; display:grid; place-items:center; color:#80736b; }.photo-button img { width:100%; height:100%; object-fit:cover; }.checkin-content { padding:16px; }.description { white-space:pre-wrap; overflow-wrap:anywhere; line-height:1.65; margin:10px 0; }.checkin-content .description { display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical; overflow:hidden; }.status-pill { border-radius:20px; padding:5px 8px; font-size:.75rem; white-space:nowrap; background:#ede8e1; }.status-pill.pending { background:#fff0cc; color:#825400; }.status-pill.awarded { background:#e2f4e8; color:#236943; }.feedback { background:#faf4ec; padding:10px; border-radius:10px; font-size:.88rem; overflow-wrap:anywhere; }.detail-button { display:block; margin-top:8px; }.empty-state { padding:40px 16px; text-align:center; color:#80736b; }.notice { padding:12px 16px; border-radius:12px; line-height:1.5; }.error { background:#ffebe6; color:#a23220; }.success { background:#e5f4e9; color:#276440; }.warning { background:#fff0cc; color:#825400; }.checkin-pagination { justify-content:center; margin:24px 0; font-size:.85rem; }.checkin-pagination button { padding:10px; border:1px solid #ded2c4; background:white; border-radius:10px; }
.checkin-dialog { width:min(640px,calc(100vw - 32px)); margin:auto; max-height:88dvh; overflow:auto; border:none; border-radius:22px; padding:24px; box-sizing:border-box; color:#3f352e; }.checkin-dialog::backdrop { background:rgb(35 25 20 / 55%); }.detail-photo { display:block; width:100%; max-height:48dvh; object-fit:contain; background:#f6f1eb; border-radius:12px; margin:16px 0; }.review-form { margin-top:20px; display:grid; gap:9px; }.review-actions { margin-top:8px; }.review-actions button { flex:1; }
@media(max-width:800px) { .checkin-grid { grid-template-columns:repeat(2,minmax(0,1fr)); } }
@media(max-width:480px) { .checkin-grid { grid-template-columns:1fr; }.upload-card { padding:16px; }.checkins-heading { align-items:flex-start; }.checkins-heading h1 { font-size:1.4rem; }.eyebrow { font-size:.75rem; }.quota { padding:7px 10px; font-size:.8rem; }.upload-footer { flex-wrap:wrap; }.upload-footer .btn { width:100%; }.checkin-dialog { padding:18px; }.checkin-pagination { gap:8px; }.filters label { min-width:130px; } }
</style>
