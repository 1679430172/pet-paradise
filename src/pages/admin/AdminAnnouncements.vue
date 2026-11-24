<template>
  <div class="admin-page announcements-page">
    <header class="admin-header">
      <div><span class="eyebrow">ADMIN CONSOLE</span><h1>公告管理</h1><p>发布登录弹窗，并查看最近的公告记录</p></div>
      <button class="logout-btn" @click="handleLogout">退出</button>
    </header>

    <section class="announcement-card card">
      <div class="announcement-heading">
        <div><span class="eyebrow">NEW ANNOUNCEMENT</span><h2>新增公告</h2><p>新增后不会覆盖已有公告；启用且已到开始时间的公告会在用户登录后依次展示。</p></div>
      </div>
      <div class="announcement-types" aria-label="公告类型">
        <button v-for="option in announcementTypes" :key="option.value" type="button" :class="{ active: announcementForm.type === option.value }" @click="announcementForm.type = option.value">
          <span>{{ option.icon }}</span><b>{{ option.label }}</b><small>{{ option.description }}</small>
        </button>
      </div>
      <div class="announcement-form">
        <div class="form-side">
          <label><span>公告标题</span><input v-model="announcementForm.title" class="form-input" maxlength="50" placeholder="例如：本周活动通知" /><small>{{ announcementForm.title.length }} / 50</small></label>
          <div class="schedule-fields">
          <div class="schedule-field"><span>开始时间 <i>可选</i></span><DateTimePicker v-model="announcementForm.startAt" label="开始时间" placeholder="选择开始时间" default-time="00:00" /><small>不设置则立即生效</small></div>
          <div class="schedule-field"><span>自动结束时间 <i>可选</i></span><DateTimePicker v-model="announcementForm.endAt" label="自动结束时间" placeholder="选择结束时间" default-time="23:59" /><small>留空则持续展示，直至手动关闭</small></div>
          </div>
        </div>
        <label class="content-field"><span>公告内容</span><textarea v-model="announcementForm.content" class="form-input" maxlength="1000" rows="6" placeholder="请输入公告内容"></textarea><small>{{ announcementForm.content.length }} / 1000</small></label>
        <label>
          <span>推送范围</span>
          <select v-model="announcementForm.scope" class="form-input">
            <option value="all">全部班级</option>
            <option value="selected">指定班级</option>
          </select>
        </label>
        <label>
          <span>接收对象</span>
          <select v-model="announcementForm.teachersOnly" class="form-input">
            <option :value="false">老师和学生</option>
            <option :value="true">仅老师</option>
          </select>
        </label>
        <div v-if="announcementForm.scope === 'selected'" class="class-picker">
          <span id="announcement-class-label" class="class-picker-label">选择班级（可多选）</span>
          <details ref="classPicker" @focusout="handleClassFocusOut" @keydown.esc.prevent.stop="closeClassPicker(true)">
            <summary class="form-input" aria-labelledby="announcement-class-label announcement-class-selection">
              <span id="announcement-class-selection" class="class-selection" :title="selectedClassLabel">
                {{ selectedClassLabel }}
              </span>
              <span v-if="announcementForm.classIds.length" class="class-count">{{ announcementForm.classIds.length }} 个</span>
              <span class="class-chevron" aria-hidden="true"></span>
            </summary>
            <div class="class-menu">
              <input v-model="classSearch" type="search" class="form-input" aria-label="搜索班级" placeholder="搜索班级名称或老师账号" />
              <div class="class-options" role="group" aria-labelledby="announcement-class-label">
                <p v-if="classesLoading">正在加载班级...</p>
                <p v-else-if="classesError">班级加载失败 <button type="button" @click="loadClasses">重试</button></p>
                <p v-else-if="!filteredClasses.length">{{ classes.length ? '没有匹配的班级' : '暂无可选班级' }}</p>
                <label v-for="item in filteredClasses" :key="item.id" class="class-option">
                  <input v-model="announcementForm.classIds" type="checkbox" :value="item.id" :disabled="announcementSaving" />
                  {{ classLabel(item) }}
                </label>
              </div>
            </div>
          </details>
        </div>
      </div>
      <div class="announcement-actions">
        <span class="save-message" role="status" aria-live="polite" :class="{ error: announcementError }">{{ announcementMessage }}</span>
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
          <div class="history-content"><strong>{{ item.title }}</strong><p>{{ item.content }}</p><small><span>{{ audienceLabel(item) }}</span><span>发布于 {{ formatDateTime(item.created_at) }}</span><span>{{ item.start_at ? `开始于 ${formatDateTime(item.start_at)}` : '立即生效' }}</span><span>{{ item.end_at ? `结束于 ${formatDateTime(item.end_at)}` : '长期展示' }}</span></small></div>
          <div class="history-actions">
            <button class="read-link" type="button" @click="openReadReceipts(item)">查看已读</button>
            <span class="history-status" :class="announcementStatus(item).className">{{ announcementStatus(item).label }}</span>
            <label class="switch compact" :class="{ disabled: announcementTogglingId === item.id || announcementStatus(item).className === 'expired' }">
              <input type="checkbox" :checked="item.enabled && announcementStatus(item).className !== 'expired'" :disabled="announcementTogglingId === item.id || announcementStatus(item).className === 'expired'" :aria-label="announcementStatus(item).className === 'expired' ? `${item.title} 已到期，无法开启` : `${item.title} ${item.enabled ? '关闭' : '开启'}`" @change="toggleAnnouncement(item)" />
              <span class="switch-track"><span></span></span>
            </label>
          </div>
        </article>
      </div>
    </section>
    <dialog ref="readDialog" class="read-dialog" aria-labelledby="read-dialog-title" @close="closeReadReceipts">
      <header>
        <div>
          <h2 id="read-dialog-title">公告已读记录</h2>
          <p>{{ readAnnouncement?.title }}</p>
        </div>
        <form method="dialog"><button class="logout-btn">关闭</button></form>
      </header>
      <ul v-if="readReceipts.length" class="read-receipts">
        <li v-for="reader in readReceipts" :key="reader.account_id">
          <div>
            <strong>{{ reader.username }}</strong>
            <span>{{ reader.account_role === 'teacher' ? '老师' : '学生' }} · {{ reader.class_name || '未分班' }}</span>
          </div>
          <time :datetime="reader.read_at">{{ formatDateTime(reader.read_at) }}</time>
        </li>
      </ul>
      <p v-if="readLoading" role="status">正在加载…</p>
      <p v-else-if="readLoadError" role="status">{{ readLoadError }}</p>
      <p v-else-if="!readReceipts.length">暂无已读记录</p>
      <button v-if="!readLoading && (hasMoreReceipts || readLoadError)" type="button" class="read-link" @click="loadReadReceipts">
        {{ readLoadError ? '重试' : '加载更多' }}
      </button>
    </dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore, type AnnouncementSetting, type AnnouncementType } from '../../stores/auth'
import { loginAuditEmail, loginAuditSupabase } from '../../lib/supabase'

import DateTimePicker from '../../components/common/DateTimePicker.vue'

const router = useRouter()
const authStore = useAuthStore()
interface ReadReceipt {
  account_id: string
  username: string
  account_role: 'teacher' | 'student'
  class_name: string | null
  read_at: string
}
const readPageSize = 50
const readDialog = ref<HTMLDialogElement | null>(null)
const readAnnouncement = ref<AnnouncementSetting | null>(null)
const readReceipts = ref<ReadReceipt[]>([])
const readLoading = ref(false)
const readLoadError = ref('')
const hasMoreReceipts = ref(false)
let receiptRequest: AbortController | undefined
const announcementSaving = ref(false)
const announcementTogglingId = ref<string | null>(null)
const announcementError = ref(false)
const announcementMessage = ref('')
const announcementForm = reactive({
  type: 'notice' as AnnouncementType,
  title: '系统公告',
  content: '',
  startAt: '',
  endAt: '',
  scope: 'all',
  classIds: [] as string[],
  teachersOnly: false,
})
type ClassOption = { id: string; username: string; class_name: string | null }
const classes = ref<ClassOption[]>([])
const classesLoading = ref(true)
const classesError = ref(false)
const classPicker = ref<HTMLDetailsElement | null>(null)
const classSearch = ref('')
const filteredClasses = computed(() => {
  const query = classSearch.value.trim().toLowerCase()
  return classes.value.filter(item =>
    (item.class_name || '').toLowerCase().includes(query) || item.username.toLowerCase().includes(query),
  )
})
const selectedClassLabel = computed(() => classes.value
  .filter(item => announcementForm.classIds.includes(item.id))
  .map(classLabel)
  .join('、') || '请选择班级')
const announcementHistory = ref<AnnouncementSetting[]>([])
const historyLoading = ref(true)
const announcementTypes: { value: AnnouncementType; icon: string; label: string; description: string }[] = [
  { value: 'notice', icon: '📣', label: '通知', description: '常规消息' }, { value: 'celebration', icon: '🎉', label: '庆祝', description: '喜讯与表扬' }, { value: 'reminder', icon: '⏰', label: '提醒', description: '时间与事项' }, { value: 'maintenance', icon: '🛠️', label: '维护', description: '服务调整' }, { value: 'other', icon: '💬', label: '其他', description: '其他内容' },
]

onMounted(() => {
  void loadAnnouncementHistory()
  void loadClasses()
  document.addEventListener('click', handleClassOutsideClick)
})
onUnmounted(() => {
  document.removeEventListener('click', handleClassOutsideClick)
  receiptRequest?.abort()
})

function openReadReceipts(item: AnnouncementSetting) {
  if (!item.id || !readDialog.value) return
  readAnnouncement.value = item
  readReceipts.value = []
  hasMoreReceipts.value = false
  readDialog.value.showModal()
  void loadReadReceipts()
}

function closeReadReceipts() {
  receiptRequest?.abort()
  receiptRequest = undefined
  readLoading.value = false
  readLoadError.value = ''
  readAnnouncement.value = null
  readReceipts.value = []
}

async function loadReadReceipts() {
  const announcementId = readAnnouncement.value?.id
  const profile = authStore.user
  if (!announcementId || !profile || !authStore.isAdmin || readLoading.value) return
  const request = new AbortController()
  receiptRequest = request
  readLoading.value = true
  readLoadError.value = ''
  try {
    const { data: { session } } = await loginAuditSupabase.auth.getSession()
    if (request.signal.aborted) return
    if (session?.user.email !== loginAuditEmail(profile.id)) {
      readLoadError.value = '请重新登录已开通日志权限的管理员账号。'
      return
    }
    const { data, error } = await loginAuditSupabase.rpc('read_announcement_receipts', {
      p_announcement_id: announcementId,
      p_after_account_id: readReceipts.value.at(-1)?.account_id ?? null,
    }).abortSignal(request.signal)
    if (request.signal.aborted) return
    if (error?.code === '42501') {
      readLoadError.value = '当前管理员账号没有公告已读记录查看权限。'
      return
    }
    if (error) throw error
    const rows: ReadReceipt[] = data ?? []
    hasMoreReceipts.value = rows.length > readPageSize
    readReceipts.value.push(...rows.slice(0, readPageSize))
  } catch {
    if (!request.signal.aborted) readLoadError.value = '已读记录加载失败，请重试。'
  } finally {
    if (receiptRequest === request) {
      receiptRequest = undefined
      readLoading.value = false
    }
  }
}

function closeClassPicker(restoreFocus = false) {
  if (!classPicker.value?.open) return
  classPicker.value.open = false
  if (restoreFocus) classPicker.value.querySelector('summary')?.focus()
}

function handleClassOutsideClick(event: MouseEvent) {
  if (event.target instanceof Node && !classPicker.value?.contains(event.target)) closeClassPicker()
}

function handleClassFocusOut(event: FocusEvent) {
  if (event.relatedTarget instanceof Node && !classPicker.value?.contains(event.relatedTarget)) closeClassPicker()
}

async function loadClasses() {
  classesLoading.value = true
  const { data, error } = await authStore.fetchRegistrationClasses()
  classes.value = data || []
  classesError.value = !!error
  classesLoading.value = false
}

function classLabel(item: ClassOption) {
  if (item.class_name === item.username) return item.username
  return `${item.class_name || '未命名班级'}（${item.username}）`
}

function audienceLabel(item: AnnouncementSetting) {
  const scope = item.target_class_ids?.map(id => {
    const target = classes.value.find(option => option.id === id)
    return target ? classLabel(target) : '班级不可用'
  }).join('、') || '全部班级'
  return `${scope} · ${item.teachers_only ? '仅老师' : '老师和学生'}`
}

async function saveAnnouncement() {
  announcementSaving.value = true; announcementError.value = false; announcementMessage.value = ''
  const result = await authStore.updateAnnouncement({
    enabled: true,
    type: announcementForm.type,
    title: announcementForm.title,
    content: announcementForm.content,
    start_at: announcementForm.startAt || null,
    end_at: announcementForm.endAt || null,
    target_class_ids: announcementForm.scope === 'selected' ? [...announcementForm.classIds] : null,
    teachers_only: announcementForm.teachersOnly,
  })
  if (result.error) { announcementError.value = true; announcementMessage.value = result.error.message || '公告保存失败' }
  else {
    announcementMessage.value = announcementForm.startAt && Date.parse(announcementForm.startAt) > Date.now() ? '新公告已新增，将在开始时间后展示。' : '新公告已新增并启用。'
    resetAnnouncementForm()
    await loadAnnouncementHistory()
  }
  announcementSaving.value = false
}

function resetAnnouncementForm() {
  announcementForm.type = 'notice'
  announcementForm.title = ''
  announcementForm.content = ''
  announcementForm.startAt = ''
  announcementForm.endAt = ''
  announcementForm.scope = 'all'
  announcementForm.classIds = []
  announcementForm.teachersOnly = false
  classSearch.value = ''
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
function announcementStatus(item: AnnouncementSetting) { if (item.end_at && Date.parse(item.end_at) <= Date.now()) return { label:'已到期', className:'expired' }; if (!item.enabled) return { label:'已停用', className:'disabled' }; if (item.start_at && Date.parse(item.start_at) > Date.now()) return { label:'待开始', className:'scheduled' }; return { label:'展示中', className:'active' } }
function formatDateTime(value?: string) { return value ? new Date(value).toLocaleString('zh-CN', { hour12:false }) : '—' }
async function handleLogout() { await authStore.signOut(); router.push('/login') }
</script>

<style scoped>
.read-link {
  padding: 6px 9px;
  border: 1px solid #e5dfed;
  border-radius: 8px;
  background: white;
  color: #6247b4;
  font-size: .75rem;
  white-space: nowrap;
  cursor: pointer;
}
.read-link:hover { background: #f5f1ff; }
.read-dialog {
  box-sizing: border-box;
  width: min(580px, calc(100% - 32px));
  max-height: 80vh;
  margin: auto;
  padding: 24px;
  border: 1px solid #e5dfed;
  border-radius: 16px;
  color: #292238;
}
.read-dialog::backdrop { background: rgb(41 34 56 / 45%); }
.read-dialog header, .read-receipts li {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  flex-wrap: wrap;
  gap: 8px 16px;
}
.read-dialog h2 { margin: 0; font-size: 1.15rem; }
.read-dialog p { margin: 8px 0; overflow-wrap: anywhere; }
.read-receipts { list-style: none; padding: 0; margin: 12px 0; }
.read-receipts li { padding: 10px 0; border-top: 1px solid #eee9f1; overflow-wrap: anywhere; }
.read-receipts span, .read-receipts time { color: #756d7b; font-size: .78rem; }
.read-receipts span { display: block; margin-top: 2px; }
.class-picker {
  grid-column: 1 / -1;
  min-width: 0;
}
.class-picker-label {
  display: block;
  margin-bottom: 7px;
  color: #655d69;
  font-size: .78rem;
  font-weight: 700;
}
.class-picker details {
  position: relative;
}
.class-picker summary {
  display: flex;
  align-items: center;
  gap: 12px;
  cursor: pointer;
  list-style: none;
}
.class-picker summary::-webkit-details-marker {
  display: none;
}
.class-selection {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}
.class-count {
  flex: none;
  padding: 2px 8px;
  border-radius: 999px;
  background: #f1ecfc;
  color: #6c4dcc;
  font-size: .75rem;
}
.class-chevron {
  width: 7px;
  height: 7px;
  margin: 0 3px 4px;
  border-right: 2px solid #756d7b;
  border-bottom: 2px solid #756d7b;
  transform: rotate(45deg);
}
.class-picker details[open] .class-chevron {
  transform: translateY(4px) rotate(225deg);
}
.class-menu {
  position: absolute;
  z-index: 5;
  inset: calc(100% + 6px) 0 auto;
  padding: 10px;
  border: 1px solid #e5dfed;
  border-radius: 11px;
  background: #fff;
  box-shadow: 0 10px 24px rgba(57, 42, 74, .14);
}
.class-options {
  max-height: 200px;
  overflow: auto;
  margin-top: 6px;
  font-size: .78rem;
}
.class-options p {
  margin: 8px;
  color: #756d7b;
}
.announcement-form .class-option {
  flex-direction: row;
  align-items: center;
  gap: 10px;
  padding: 8px;
  border-radius: 7px;
  overflow-wrap: anywhere;
  cursor: pointer;
}
.class-option:hover,
.class-option:focus-within {
  background: #f5f1ff;
}
.class-option input {
  flex: none;
  margin: 0;
  accent-color: var(--admin-purple);
}
.admin-page { --admin-purple:#7657d5; --admin-ink:#292238; min-height:100vh; padding:38px 28px 100px; background:#f8f7fb; color:var(--admin-ink); }.admin-header,.announcement-card,.history-card { box-sizing:border-box; max-width:1120px; margin-left:auto; margin-right:auto; }.admin-header { margin-bottom:24px; display:flex; justify-content:space-between; align-items:flex-end; gap:24px; }.eyebrow { color:#9a8ab6; font-size:.68rem; font-weight:800; letter-spacing:.16em; }.admin-header h1 { margin:6px 0 4px; font-size:2rem; letter-spacing:-.04em; }.admin-header p,.announcement-heading p { margin:0; color:#8a8392; font-size:.86rem; }.logout-btn { padding:10px 16px; border:1px solid #e7e3ec; border-radius:11px; color:#6f6877; background:white; cursor:pointer; font-weight:700; }.announcement-card,.history-card { padding:26px; border:1px solid #ece8f0; border-radius:18px; box-shadow:0 6px 22px rgba(57,42,74,.055); }.announcement-heading { display:flex; align-items:center; justify-content:space-between; gap:24px; }.announcement-heading h2,.history-heading h2 { margin:5px 0 4px; font-size:1.15rem; }.publish-control { display:flex; align-items:center; gap:10px; flex:none; color:#8a8392; font-size:.72rem; font-weight:700; }.announcement-types { display:grid; grid-template-columns:repeat(5,1fr); gap:9px; margin-top:20px; }.announcement-types button { display:grid; grid-template-columns:auto 1fr; align-items:center; gap:2px 8px; min-height:58px; padding:11px 13px; border:1px solid #e9e4ed; border-radius:12px; color:#655d69; background:#fff; cursor:pointer; text-align:left; transition:border-color .18s,background .18s,transform .18s; }.announcement-types button:hover { border-color:#cfc2ed; background:#fbf9ff; }.announcement-types button>span { grid-row:1/3; font-size:1.2rem; }.announcement-types b { font-size:.78rem; }.announcement-types small { color:#9a929f; font-size:.66rem; }.announcement-types button.active { border-color:#8d72dc; color:#6c4dcc; background:#f5f1ff; box-shadow:0 0 0 2px rgba(118,87,213,.08); }.announcement-form { display:grid; grid-template-columns:minmax(0,1fr) minmax(0,1fr); gap:18px; margin-top:20px; }.form-side { display:flex; flex-direction:column; gap:18px; min-width:0; }.schedule-fields { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:14px; padding-top:16px; border-top:1px solid #f0ecf2; }.schedule-fields small { align-self:flex-start; line-height:1.5; }.announcement-form label,.schedule-field { display:flex; flex-direction:column; gap:7px; color:#655d69; font-size:.78rem; font-weight:700; }.announcement-form label span,.schedule-field>span { display:flex; align-items:center; gap:7px; }.announcement-form label i,.schedule-field i { padding:2px 6px; border-radius:999px; color:#968da0; background:#f1eef4; font-size:.62rem; font-style:normal; font-weight:600; }.announcement-form textarea { box-sizing:border-box; resize:vertical; min-height:160px; line-height:1.7; font-family:inherit; }.announcement-form small { align-self:flex-end; color:#a49daa; font-size:.68rem; font-weight:400; }.content-field { min-width:0; }.content-field textarea { flex:1; min-height:178px; }.announcement-form .form-input { box-sizing:border-box; width:100%; min-width:0; border-color:#e5dfed; border-radius:11px; background:#fdfcfe; transition:border-color .18s,box-shadow .18s; }.announcement-form .form-input:focus { border-color:#9b80e2; box-shadow:0 0 0 3px rgba(118,87,213,.1); background:#fff; }.schedule-fields input { padding:12px 10px; font-size:.82rem; }.announcement-types button:focus-visible,.primary-action:focus-visible { outline:3px solid #c8b8ed; outline-offset:3px; }.announcement-actions { display:flex; justify-content:flex-end; align-items:center; gap:14px; margin-top:18px; padding-top:18px; border-top:1px solid #f0ecf2; }.primary-action { min-width:96px; padding:10px 16px; border:0; border-radius:11px; color:white; background:var(--admin-purple); box-shadow:0 6px 16px rgba(118,87,213,.2); cursor:pointer; font-weight:700; }.primary-action:disabled { opacity:.55; cursor:wait; }.save-message { flex:1; min-height:1.5em; line-height:1.5; color:#36865c; font-size:.8rem; }.save-message.error { color:#c7475e; }.switch { cursor:pointer; }.switch.disabled { opacity:.55; cursor:wait; }.switch input { position:absolute; opacity:0; pointer-events:none; }.switch-track { width:46px; height:26px; display:block; padding:3px; border-radius:99px; background:#d8d4dc; transition:.2s; }.switch-track span { width:20px; height:20px; display:block; border-radius:50%; background:white; box-shadow:0 1px 4px rgba(0,0,0,.18); transition:.2s; }.switch input:checked+.switch-track { background:#38bd72; }.switch input:checked+.switch-track span { transform:translateX(20px); }.switch.compact .switch-track { width:38px; height:22px; padding:2px; }.switch.compact .switch-track span { width:18px; height:18px; }.switch.compact input:checked+.switch-track span { transform:translateX(16px); }.history-card { margin-top:20px; }.history-heading { display:flex; align-items:flex-end; justify-content:space-between; }.history-heading>span { color:#9a929f; font-size:.7rem; }.history-list { display:grid; gap:10px; margin-top:16px; }.history-list article { display:grid; grid-template-columns:40px minmax(0,1fr) auto; align-items:center; gap:14px; padding:15px 16px; border:1px solid #eee9f1; border-radius:13px; background:#fcfbfd; transition:border-color .18s,background .18s; }.history-list article:hover { border-color:#dfd6e9; background:#fff; }.history-icon { width:36px; height:36px; display:grid; place-items:center; border-radius:10px; background:#f2eef9; font-size:1.05rem; }.history-content { min-width:0; }.history-list strong { font-size:.82rem; }.history-list p { display:-webkit-box; overflow:hidden; margin:5px 0 7px; color:#756d7b; font-size:.72rem; line-height:1.55; -webkit-box-orient:vertical; -webkit-line-clamp:2; }.history-list small { display:flex; flex-wrap:wrap; gap:5px 14px; color:#aaa2ae; font-size:.64rem; }.history-actions { display:flex; align-items:center; gap:10px; }.history-status { padding:5px 9px; border-radius:999px; font-size:.66rem; font-weight:700; white-space:nowrap; }.history-status.active { color:#198452; background:#e5f7ed; }.history-status.scheduled { color:#7657d5; background:#f1ecfc; }.history-status.expired { color:#9b7419; background:#fff3d7; }.history-status.disabled { color:#817987; background:#efedf1; }.history-empty { padding:32px; color:#999; text-align:center; font-size:.75rem; }
@media (max-width:1100px) { .announcement-form { grid-template-columns:1fr; }.announcement-types { grid-template-columns:repeat(3,1fr); } }
@media (max-width:700px) { .admin-page { padding:24px 16px 90px; }.admin-header { align-items:flex-start; }.admin-header h1 { font-size:1.6rem; }.announcement-card,.history-card { padding:19px; border-radius:15px; }.announcement-heading { align-items:flex-start; }.publish-control { flex-direction:column-reverse; align-items:flex-end; gap:5px; }.announcement-types { grid-template-columns:repeat(2,1fr); }.history-list article { grid-template-columns:36px minmax(0,1fr); padding:13px; }.history-actions { grid-column:2; justify-content:space-between; }.announcement-actions { justify-content:space-between; } }
@media (max-width:480px) { .schedule-fields { grid-template-columns:1fr; gap:16px; }.announcement-actions { align-items:flex-start; flex-direction:column; gap:8px; }.primary-action { align-self:flex-end; }.announcement-heading p { line-height:1.65; } }
</style>
