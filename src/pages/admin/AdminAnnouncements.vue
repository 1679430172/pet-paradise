<template>
  <div class="admin-page announcements-page">
    <header class="admin-header">
      <div><span class="eyebrow">ADMIN CONSOLE</span><h1>公告管理</h1><p>发布登录弹窗，并查看最近的公告记录</p></div>
      <button class="logout-btn" @click="handleLogout">退出</button>
    </header>

    <section class="announcement-card card">
      <div class="announcement-heading">
        <div><span class="eyebrow">NEW ANNOUNCEMENT</span><h2>新增公告</h2><p>新增后不会覆盖已有公告；启用的公告会在用户登录后依次展示。</p></div>
      </div>
      <div class="announcement-types" aria-label="公告类型">
        <button v-for="option in announcementTypes" :key="option.value" type="button" :class="{ active: announcementForm.type === option.value }" @click="announcementForm.type = option.value">
          <span>{{ option.icon }}</span><b>{{ option.label }}</b><small>{{ option.description }}</small>
        </button>
      </div>
      <div class="announcement-form">
        <div class="form-side">
          <label><span>公告标题</span><input v-model="announcementForm.title" class="form-input" maxlength="50" placeholder="例如：本周活动通知" /><small>{{ announcementForm.title.length }} / 50</small></label>
          <label><span>自动结束时间 <i>可选</i></span><input v-model="announcementForm.endAt" class="form-input" type="datetime-local" :min="minimumEndTime" /><small>不设置则持续展示，直至手动关闭</small></label>
        </div>
        <label class="content-field"><span>公告内容</span><textarea v-model="announcementForm.content" class="form-input" maxlength="1000" rows="6" placeholder="请输入要通知老师和学生的内容"></textarea><small>{{ announcementForm.content.length }} / 1000</small></label>
      </div>
      <div class="announcement-actions">
        <span v-if="announcementMessage" class="save-message" :class="{ error: announcementError }">{{ announcementMessage }}</span>
        <button class="primary-action" :disabled="announcementSaving" @click="saveAnnouncement">{{ announcementSaving ? '新增中...' : '新增公告' }}</button>
      </div>
    </section>

    <section class="history-card card">
      <div class="history-heading"><div><span class="eyebrow">HISTORY</span><h2>历史记录</h2></div><span>最近 {{ announcementHistory.length }} 条</span></div>
      <div v-if="historyLoading" class="history-empty">正在加载...</div>
      <div v-else-if="announcementHistory.length === 0" class="history-empty">还没有发布记录</div>
      <div v-else class="history-list">
        <article v-for="item in announcementHistory" :key="item.id">
          <span class="history-icon">{{ announcementTypeMeta(item.type).icon }}</span>
          <div class="history-content"><strong>{{ item.title }}</strong><p>{{ item.content }}</p><small><span>发布于 {{ formatDateTime(item.created_at) }}</span><span>{{ item.end_at ? `结束于 ${formatDateTime(item.end_at)}` : '长期展示' }}</span></small></div>
          <div class="history-actions">
            <span class="history-status" :class="announcementStatus(item).className">{{ announcementStatus(item).label }}</span>
            <label class="switch compact" :class="{ disabled: announcementTogglingId === item.id || announcementStatus(item).className === 'expired' }">
              <input type="checkbox" :checked="announcementStatus(item).className === 'active'" :disabled="announcementTogglingId === item.id || announcementStatus(item).className === 'expired'" :aria-label="announcementStatus(item).className === 'expired' ? `${item.title} 已到期，无法开启` : `${item.title} ${item.enabled ? '关闭' : '开启'}`" @change="toggleAnnouncement(item)" />
              <span class="switch-track"><span></span></span>
            </label>
          </div>
        </article>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore, type AnnouncementSetting, type AnnouncementType } from '../../stores/auth'

const router = useRouter()
const authStore = useAuthStore()
const announcementSaving = ref(false)
const announcementTogglingId = ref<string | null>(null)
const announcementError = ref(false)
const announcementMessage = ref('')
const announcementForm = reactive<{ type: AnnouncementType; title: string; content: string; endAt: string }>({ type: 'notice', title: '系统公告', content: '', endAt: '' })
const announcementHistory = ref<AnnouncementSetting[]>([])
const historyLoading = ref(true)
const minimumEndTime = computed(() => toDateTimeLocal(new Date(Date.now() + 60 * 1000)))
const announcementTypes: { value: AnnouncementType; icon: string; label: string; description: string }[] = [
  { value: 'notice', icon: '📣', label: '通知', description: '常规消息' }, { value: 'celebration', icon: '🎉', label: '庆祝', description: '喜讯与表扬' }, { value: 'reminder', icon: '⏰', label: '提醒', description: '时间与事项' }, { value: 'maintenance', icon: '🛠️', label: '维护', description: '服务调整' }, { value: 'other', icon: '💬', label: '其他', description: '其他内容' },
]

onMounted(loadAnnouncementHistory)

async function saveAnnouncement() {
  announcementSaving.value = true; announcementError.value = false; announcementMessage.value = ''
  const result = await authStore.updateAnnouncement({ enabled: true, type: announcementForm.type, title: announcementForm.title, content: announcementForm.content, end_at: announcementForm.endAt ? new Date(announcementForm.endAt).toISOString() : null })
  if (result.error) { announcementError.value = true; announcementMessage.value = result.error.message || '公告保存失败' }
  else {
    announcementMessage.value = '新公告已新增并启用。'
    resetAnnouncementForm()
    await loadAnnouncementHistory()
  }
  announcementSaving.value = false
}

function resetAnnouncementForm() {
  announcementForm.type = 'notice'
  announcementForm.title = ''
  announcementForm.content = ''
  announcementForm.endAt = ''
}

async function toggleAnnouncement(item: AnnouncementSetting) {
  if (!item.id) return
  announcementTogglingId.value = item.id
  announcementError.value = false
  announcementMessage.value = ''
  const nextEnabled = !item.enabled
  const result = await authStore.updateAnnouncementEnabled(item.id, nextEnabled)
  if (result.error) {
    announcementError.value = true
    announcementMessage.value = result.error.message || '公告状态修改失败'
  } else {
    item.enabled = nextEnabled
    announcementMessage.value = `“${item.title}”已${nextEnabled ? '开启' : '关闭'}。`
  }
  announcementTogglingId.value = null
}

async function loadAnnouncementHistory() { historyLoading.value = true; const result = await authStore.fetchAnnouncementHistory(); announcementHistory.value = (result.data || []) as AnnouncementSetting[]; historyLoading.value = false }
function announcementTypeMeta(type: AnnouncementType) { return announcementTypes.find(item => item.value === type) || announcementTypes[0] }
function announcementStatus(item: AnnouncementSetting) { if (item.end_at && Date.parse(item.end_at) <= Date.now()) return { label:'已到期', className:'expired' }; if (!item.enabled) return { label:'已停用', className:'disabled' }; return { label:'展示中', className:'active' } }
function toDateTimeLocal(date: Date) { const offset = date.getTimezoneOffset() * 60_000; return new Date(date.getTime() - offset).toISOString().slice(0,16) }
function formatDateTime(value?: string) { return value ? new Date(value).toLocaleString('zh-CN', { hour12:false }) : '—' }
async function handleLogout() { await authStore.signOut(); router.push('/login') }
</script>

<style scoped>
.admin-page { --admin-purple:#7657d5; --admin-ink:#292238; min-height:100vh; padding:38px 28px 100px; background:#f8f7fb; color:var(--admin-ink); }.admin-header,.announcement-card,.history-card { box-sizing:border-box; max-width:1120px; margin-left:auto; margin-right:auto; }.admin-header { margin-bottom:24px; display:flex; justify-content:space-between; align-items:flex-end; gap:24px; }.eyebrow { color:#9a8ab6; font-size:.68rem; font-weight:800; letter-spacing:.16em; }.admin-header h1 { margin:6px 0 4px; font-size:2rem; letter-spacing:-.04em; }.admin-header p,.announcement-heading p { margin:0; color:#8a8392; font-size:.86rem; }.logout-btn { padding:10px 16px; border:1px solid #e7e3ec; border-radius:11px; color:#6f6877; background:white; cursor:pointer; font-weight:700; }.announcement-card,.history-card { padding:26px; border:1px solid #ece8f0; border-radius:18px; box-shadow:0 6px 22px rgba(57,42,74,.055); }.announcement-heading { display:flex; align-items:center; justify-content:space-between; gap:24px; }.announcement-heading h2,.history-heading h2 { margin:5px 0 4px; font-size:1.15rem; }.publish-control { display:flex; align-items:center; gap:10px; flex:none; color:#8a8392; font-size:.72rem; font-weight:700; }.announcement-types { display:grid; grid-template-columns:repeat(5,1fr); gap:9px; margin-top:20px; }.announcement-types button { display:grid; grid-template-columns:auto 1fr; align-items:center; gap:2px 8px; min-height:58px; padding:11px 13px; border:1px solid #e9e4ed; border-radius:12px; color:#655d69; background:#fff; cursor:pointer; text-align:left; transition:border-color .18s,background .18s,transform .18s; }.announcement-types button:hover { border-color:#cfc2ed; background:#fbf9ff; }.announcement-types button>span { grid-row:1/3; font-size:1.2rem; }.announcement-types b { font-size:.78rem; }.announcement-types small { color:#9a929f; font-size:.66rem; }.announcement-types button.active { border-color:#8d72dc; color:#6c4dcc; background:#f5f1ff; box-shadow:0 0 0 2px rgba(118,87,213,.08); }.announcement-form { display:grid; grid-template-columns:minmax(250px,.72fr) minmax(360px,1.28fr); gap:18px; margin-top:20px; }.form-side { display:flex; flex-direction:column; gap:17px; }.announcement-form label { display:flex; flex-direction:column; gap:7px; color:#655d69; font-size:.78rem; font-weight:700; }.announcement-form label span { display:flex; align-items:center; gap:7px; }.announcement-form label i { padding:2px 6px; border-radius:999px; color:#968da0; background:#f1eef4; font-size:.62rem; font-style:normal; font-weight:600; }.announcement-form textarea { box-sizing:border-box; resize:vertical; min-height:160px; line-height:1.7; font-family:inherit; }.announcement-form small { align-self:flex-end; color:#a49daa; font-size:.68rem; font-weight:400; }.content-field { min-width:0; }.announcement-actions { display:flex; justify-content:flex-end; align-items:center; gap:14px; margin-top:18px; padding-top:18px; border-top:1px solid #f0ecf2; }.primary-action { min-width:96px; padding:10px 16px; border:0; border-radius:11px; color:white; background:var(--admin-purple); box-shadow:0 6px 16px rgba(118,87,213,.2); cursor:pointer; font-weight:700; }.primary-action:disabled { opacity:.55; cursor:wait; }.save-message { color:#36865c; font-size:.8rem; }.save-message.error { color:#c7475e; }.switch { cursor:pointer; }.switch.disabled { opacity:.55; cursor:wait; }.switch input { position:absolute; opacity:0; pointer-events:none; }.switch-track { width:46px; height:26px; display:block; padding:3px; border-radius:99px; background:#d8d4dc; transition:.2s; }.switch-track span { width:20px; height:20px; display:block; border-radius:50%; background:white; box-shadow:0 1px 4px rgba(0,0,0,.18); transition:.2s; }.switch input:checked+.switch-track { background:#38bd72; }.switch input:checked+.switch-track span { transform:translateX(20px); }.switch.compact .switch-track { width:38px; height:22px; padding:2px; }.switch.compact .switch-track span { width:18px; height:18px; }.switch.compact input:checked+.switch-track span { transform:translateX(16px); }.history-card { margin-top:20px; }.history-heading { display:flex; align-items:flex-end; justify-content:space-between; }.history-heading>span { color:#9a929f; font-size:.7rem; }.history-list { display:grid; gap:10px; margin-top:16px; }.history-list article { display:grid; grid-template-columns:40px minmax(0,1fr) auto; align-items:center; gap:14px; padding:15px 16px; border:1px solid #eee9f1; border-radius:13px; background:#fcfbfd; transition:border-color .18s,background .18s; }.history-list article:hover { border-color:#dfd6e9; background:#fff; }.history-icon { width:36px; height:36px; display:grid; place-items:center; border-radius:10px; background:#f2eef9; font-size:1.05rem; }.history-content { min-width:0; }.history-list strong { font-size:.82rem; }.history-list p { display:-webkit-box; overflow:hidden; margin:5px 0 7px; color:#756d7b; font-size:.72rem; line-height:1.55; -webkit-box-orient:vertical; -webkit-line-clamp:2; }.history-list small { display:flex; flex-wrap:wrap; gap:5px 14px; color:#aaa2ae; font-size:.64rem; }.history-actions { display:flex; align-items:center; gap:10px; }.history-status { padding:5px 9px; border-radius:999px; font-size:.66rem; font-weight:700; white-space:nowrap; }.history-status.active { color:#198452; background:#e5f7ed; }.history-status.expired { color:#9b7419; background:#fff3d7; }.history-status.disabled { color:#817987; background:#efedf1; }.history-empty { padding:32px; color:#999; text-align:center; font-size:.75rem; }
@media (max-width:820px) { .announcement-form { grid-template-columns:1fr; }.announcement-types { grid-template-columns:repeat(3,1fr); } }
@media (max-width:700px) { .admin-page { padding:24px 16px 90px; }.admin-header { align-items:flex-start; }.admin-header h1 { font-size:1.6rem; }.announcement-card,.history-card { padding:19px; border-radius:15px; }.announcement-heading { align-items:flex-start; }.publish-control { flex-direction:column-reverse; align-items:flex-end; gap:5px; }.announcement-types { grid-template-columns:repeat(2,1fr); }.history-list article { grid-template-columns:36px minmax(0,1fr); padding:13px; }.history-actions { grid-column:2; justify-content:space-between; }.announcement-actions { justify-content:space-between; } }
</style>
