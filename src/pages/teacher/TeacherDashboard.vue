<template>
  <div class="page teacher-page dashboard-page">
    <div class="teacher-header">
      <h1>教师后台</h1>
      <button class="btn-logout" @click="handleLogout">退出</button>
    </div>

    <div class="stats-grid">
      <div class="stat-card">
        <span class="stat-icon">👥</span>
        <span class="stat-value">{{ teacherStore.totalStudents }}</span>
        <span class="stat-label">学生总数</span>
      </div>
      <div class="stat-card">
        <span class="stat-icon">📋</span>
        <span class="stat-value">{{ tasksStore.tasks.length }}</span>
        <span class="stat-label">活跃任务</span>
      </div>
      <div class="stat-card">
        <span class="stat-icon">⭐</span>
        <span class="stat-value">{{ teacherStore.totalPointsGiven }}</span>
        <span class="stat-label">有效发放积分</span>
      </div>
    </div>

    <p v-if="revokeMessage" class="revoke-message" role="status">{{ revokeMessage }}</p>
    <div class="section">
      <h3>积分发放记录</h3>
      <div v-if="recordsLoading" class="empty-state" role="status">加载中...</div>
      <div v-else-if="recordsError" class="empty-state" role="alert">
        {{ recordsError }}
        <button class="page-button" @click="fetchRecentCompletions(requestedPage)">重试</button>
      </div>
      <div v-else-if="recentCompletions.length === 0" class="empty-state">暂无记录</div>
      <div v-else class="completion-list">
        <div v-for="c in recentCompletions" :key="c.id" class="completion-item card">
          <div class="completion-info">
            <span class="completion-student">{{ c.student_username }}</span>
            <span class="completion-task">{{ c.task_name }}</span>
            <small class="completion-date">{{ formatTime(c.created_at) }}</small>
          </div>
          <span class="completion-points" :class="{ 'revoked-points': c.revoked_at }">+{{ c.points }}</span>
          <span v-if="c.revoked_at" class="revoked-label">已撤销</span>
          <button v-else class="revoke-button" @click="openRevoke(c)">撤销</button>
          <button v-if="c.revoked_at" class="completion-note revoked-detail" :title="`${formatTime(c.revoked_at)} · ${c.revoke_reason}`" @click="detailTarget = c">{{ formatTime(c.revoked_at) }} · {{ c.revoke_reason }} · 查看详情</button>
          <span v-else class="completion-note">有效奖励</span>
        </div>
      </div>
      <nav class="pagination" aria-label="发放记录分页">
        <span>共 {{ totalRecords }} 条 · 每页 {{ pageSize }} 条</span>
        <div class="page-actions">
          <button class="page-button" :disabled="recordsLoading || currentPage <= 1" @click="fetchRecentCompletions(currentPage - 1)">上一页</button>
          <span aria-live="polite">第 {{ currentPage }} / {{ totalPages }} 页</span>
          <button class="page-button" :disabled="recordsLoading || currentPage >= totalPages" @click="fetchRecentCompletions(currentPage + 1)">下一页</button>
        </div>
      </nav>
    </div>
    <div v-if="detailTarget" class="revoke-overlay" @click.self="detailTarget = null" @keydown.esc="detailTarget = null">
      <div class="revoke-dialog card" role="dialog" aria-modal="true" aria-labelledby="revoke-detail-title">
        <h3 id="revoke-detail-title">撤销详情</h3>
        <p>{{ detailTarget.student_username }} · {{ detailTarget.task_name }} · {{ detailTarget.points }} 分</p>
        <p class="revoke-hint">{{ formatTime(detailTarget.revoked_at!) }}</p>
        <p class="full-revoke-reason">{{ detailTarget.revoke_reason }}</p>
        <button class="btn btn-secondary" @click="detailTarget = null">关闭</button>
      </div>
    </div>
    <div v-if="revokeTarget" class="revoke-overlay" @click.self="closeRevoke" @keydown.esc="closeRevoke">
      <form class="revoke-dialog card" role="dialog" aria-modal="true" aria-labelledby="revoke-title" @submit.prevent="confirmRevoke">
        <h3 id="revoke-title">撤销这笔奖励？</h3>
        <p><strong>{{ revokeTarget.student_username }}</strong> · {{ revokeTarget.task_name }} · {{ revokeTarget.points }} 分</p>
        <p class="revoke-hint">将收回这笔积分并修正排行榜，保留原记录。已获得的宠物成长不回退；余额不足时不会扣成负数。</p>
        <label for="revoke-reason">撤销原因</label>
        <textarea id="revoke-reason" ref="reasonInput" v-model="revokeReason" class="form-input" maxlength="200" rows="3" required placeholder="例如：选错学生、重复发放" :disabled="revoking" />
        <p v-if="revokeError" role="alert" class="revoke-error">{{ revokeError }}</p>
        <div class="revoke-actions"><button type="button" class="btn btn-secondary" :disabled="revoking" @click="closeRevoke">取消</button>
          <button class="btn btn-primary" type="submit" :disabled="revoking || !revokeReason.trim()">{{ revoking ? '正在撤销...' : '确认撤销' }}</button></div>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, nextTick, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'
import { useTeacherStore } from '../../stores/teacher'
import { useTasksStore } from '../../stores/tasks'
import { supabase } from '../../lib/supabase'

const router = useRouter()
const authStore = useAuthStore()
const teacherStore = useTeacherStore()
const tasksStore = useTasksStore()

interface RecentCompletion {
  revoked_at: string | null
  revoke_reason: string | null
  id: string
  points: number
  student_username: string
  task_name: string
  created_at: string
}
const recentCompletions = ref<RecentCompletion[]>([])
const pageSize = 10
const currentPage = ref(1)
const requestedPage = ref(1)
const totalRecords = ref(0)
const totalPages = computed(() => Math.max(1, Math.ceil(totalRecords.value / pageSize)))
const recordsLoading = ref(false)
const recordsError = ref('')
const revokeTarget = ref<RecentCompletion | null>(null)
const detailTarget = ref<RecentCompletion | null>(null)
const revokeReason = ref('')
const revokeError = ref('')
const revokeMessage = ref('')
const revoking = ref(false)
const reasonInput = ref<HTMLTextAreaElement | null>(null)
function formatTime(value: string) {
  return new Date(value).toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai', hour12: false })
}
function openRevoke(record: RecentCompletion) {
  revokeTarget.value = record
  revokeReason.value = ''
  revokeError.value = ''
  revokeMessage.value = ''
  void nextTick(() => reasonInput.value?.focus())
}
function closeRevoke() { if (!revoking.value) revokeTarget.value = null }
async function confirmRevoke() {
  if (!revokeTarget.value || revoking.value || !revokeReason.value.trim()) return
  revoking.value = true
  revokeError.value = ''
  try {
    const result = await tasksStore.revokeAward(revokeTarget.value.id, revokeReason.value.trim())
    Object.assign(revokeTarget.value, result.completion)
    revokeMessage.value = result.alreadyRevoked ? '这笔奖励已经撤销，没有重复扣分。' : `已撤销奖励，学生当前余额为 ${result.balance} 分。`
    revokeTarget.value = null
    await teacherStore.fetchStats()
  } catch (error) {
    revokeError.value = error instanceof Error ? error.message : '撤销失败，请重试'
  } finally { revoking.value = false }
}

onMounted(async () => {
  await Promise.all([
    teacherStore.fetchStats(),
    tasksStore.fetchTasks(),
    fetchRecentCompletions(),
  ])
})

async function fetchRecentCompletions(page = 1) {
  if (!authStore.user || recordsLoading.value) return
  const teacherId = authStore.user.id
  requestedPage.value = Math.max(1, page)
  recordsLoading.value = true
  recordsError.value = ''
  try {
    // If records were deleted since the previous request, fall back to the last page.
    while (true) {
      const from = (requestedPage.value - 1) * pageSize
      const { data, count, error } = await supabase
        .from('task_completions')
        .select('id, points, created_at, revoked_at, revoke_reason, student:profiles!task_completions_student_id_fkey(username), task:tasks(name)', { count: 'exact' })
        .eq('awarded_by', teacherId)
        .order('created_at', { ascending: false })
        .order('id', { ascending: false })
        .range(from, from + pageSize - 1)
      if (error) throw error
      const lastPage = Math.max(1, Math.ceil((count ?? 0) / pageSize))
      if (requestedPage.value > lastPage) {
        requestedPage.value = lastPage
        continue
      }
      recentCompletions.value = (data || []).map((d: any) => ({
        id: d.id,
        points: d.points,
        student_username: d.student?.username || '未知',
        task_name: d.task?.name || '未知任务',
        created_at: d.created_at,
        revoked_at: d.revoked_at,
        revoke_reason: d.revoke_reason,
      }))
      totalRecords.value = count ?? 0
      currentPage.value = requestedPage.value
      break
    }
  } catch {
    recordsError.value = '记录加载失败，请重试。'
  } finally {
    recordsLoading.value = false
  }
}

async function handleLogout() {
  await authStore.signOut()
  router.push('/login')
}
</script>

<style scoped>
.completion-date { color: #89918c; font-size: 12px; }
.revoked-detail { color: #8b7762; border: 0; padding: 0; background: none; cursor: pointer; text-align: left; }
.completion-note { grid-column: 1 / -1; display: block; min-width: 0; font-size: 12px; line-height: 20px; height: 20px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: #8b8f89; }
.revoked-detail:hover { color: #91602f; text-decoration: underline; }
.full-revoke-reason { overflow-wrap: anywhere; white-space: pre-wrap; }
.revoked-points { text-decoration: line-through; opacity: .5; }
.revoked-label { color: #999; font-size: 13px; white-space: nowrap; }
.revoke-button { background: #fff8f0; color: #987044; border: 1px solid #ecdfcf; padding: 6px 12px; border-radius: 8px; cursor: pointer; white-space: nowrap; }
.revoke-message { background: #eaf5ed; color: #36795c; padding: 12px; border-radius: 10px; }
.revoke-overlay { position: fixed; inset: 0; z-index: 1000; background: #0006; display: grid; place-items: center; padding: 20px; }
.revoke-dialog { width: min(100%, 460px); max-height: 90dvh; overflow: auto; padding: 24px; display: grid; gap: 16px; }
.revoke-hint { color: #778079; font-size: 13px; line-height: 1.7; }
.revoke-actions { display: flex; justify-content: flex-end; gap: 12px; }
.revoke-error { color: #b74545; }

.teacher-page {
  padding-bottom: 80px;
}

.teacher-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.teacher-header h1 {
  font-size: 1.5rem;
  color: var(--color-primary);
}

.btn-logout {
  padding: 6px 14px;
  border-radius: 8px;
  border: 1px solid #ddd;
  background: white;
  color: #666;
  cursor: pointer;
  font-size: 0.85rem;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
  margin-bottom: 24px;
}

.stat-card {
  background: white;
  border-radius: 12px;
  padding: 16px 12px;
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
}

.stat-icon {
  font-size: 1.5rem;
}

.stat-value {
  font-size: 1.4rem;
  font-weight: 700;
  color: var(--color-primary);
}

.stat-label {
  font-size: 0.75rem;
  color: #999;
}

.section h3 {
  font-size: 1rem;
  margin-bottom: 12px;
  color: #333;
}

.empty-state {
  text-align: center;
  color: #999;
  padding: 24px;
  font-size: 0.9rem;
}

.completion-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.dashboard-page .completion-item {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto 52px;
  grid-template-rows: minmax(0, 1fr) 20px;
  align-items: center;
  gap: 6px 12px;
  height: 132px;
  padding: 12px 16px;
}
.completion-info > span, .completion-date { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.completion-points { white-space: nowrap; }
.revoke-button, .revoked-label { justify-self: end; }

.completion-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.completion-student {
  font-weight: 600;
  font-size: 0.9rem;
}

.completion-task {
  font-size: 0.8rem;
  color: #999;
}

.completion-points {
  font-weight: 700;
  color: var(--color-success);
  font-size: 1.1rem;
}

.pagination, .page-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 12px;
}

.pagination {
  margin-top: 16px;
  color: var(--color-text-muted);
  font-size: .85rem;
}

.page-button {
  padding: 7px 12px;
  border: 1px solid #eadfD3;
  border-radius: 8px;
  background: white;
  color: var(--color-primary);
  cursor: pointer;
}

.page-button:disabled {
  opacity: .45;
  cursor: not-allowed;
}
</style>
