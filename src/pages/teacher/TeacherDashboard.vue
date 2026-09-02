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
        <span class="stat-label">已发积分</span>
      </div>
    </div>

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
          </div>
          <span class="completion-points">+{{ c.points }}</span>
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
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
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
        .select('id, points, created_at, student:profiles!task_completions_student_id_fkey(username), task:tasks(name)', { count: 'exact' })
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

.completion-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
}

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
