<template>
  <div class="page teacher-page">
    <div class="header-row">
      <div>
        <h1 class="page-title">学生管理</h1>
        <p class="class-label">{{ authStore.user?.class_name || '默认班级' }}</p>
      </div>
      <button class="btn btn-primary btn-sm" @click="showCreateDialog = true">+ 新增学生</button>
    </div>

    <div class="search-bar">
      <input
        v-model="searchQuery"
        type="text"
        class="form-input"
        placeholder="搜索学生..."
        @input="handleSearch"
      />
    </div>

    <div v-if="teacherStore.students.length > 0" class="batch-toolbar card">
      <label class="select-all">
        <input
          type="checkbox"
          :checked="allVisibleSelected"
          :indeterminate="someVisibleSelected"
          @change="toggleSelectAll"
        />
        <span>{{ allVisibleSelected ? '取消全选' : '全选当前学生' }}</span>
      </label>
      <span class="selected-count">已选 {{ selectedStudentIds.length }} 人</span>
      <button
        class="btn btn-primary btn-sm"
        :disabled="selectedStudentIds.length === 0"
        @click="openBatchAwardDialog"
      >
        批量发积分
      </button>
    </div>

    <div v-if="teacherStore.loading" class="loading-state">加载中...</div>
    <div v-else-if="teacherStore.students.length === 0" class="empty-state">暂无学生</div>
    <div v-else class="student-list">
      <div
        v-for="student in teacherStore.students"
        :key="student.id"
        class="student-card card"
      >
        <label class="student-selector" @click.stop>
          <input
            type="checkbox"
            :checked="selectedStudentIds.includes(student.id)"
            :aria-label="`选择学生 ${student.username}`"
            @change="toggleStudent(student.id)"
          />
        </label>
        <div class="student-info" @click="goDetail(student.id)">
          <div class="student-avatar">{{ student.username.charAt(0) }}</div>
          <div class="student-meta">
            <span class="student-name">{{ student.username }}</span>
            <span class="student-points">{{ student.points }} 积分</span>
          </div>
        </div>
        <div class="student-actions">
          <button class="btn btn-primary btn-sm" @click="openAwardDialog(student)">发积分</button>
          <button class="btn btn-danger btn-sm" @click="handleDelete(student)">删除</button>
        </div>
      </div>
    </div>

    <!-- 发积分弹窗 -->
    <div v-if="showDialog" class="dialog-overlay" @click.self="showDialog = false">
      <div class="dialog card">
        <h3>{{ awardDialogTitle }}</h3>
        <p class="dialog-hint">选择已完成的任务：</p>
        <div v-if="tasksStore.tasks.length === 0" class="empty-state">暂无任务，请先创建任务</div>
        <div v-else class="task-select-list">
          <div
            v-for="task in tasksStore.tasks"
            :key="task.id"
            class="task-select-item"
            :class="{ disabled: awarding }"
            @click="confirmAward(task)"
          >
            <div class="task-select-info">
              <span class="task-name">{{ task.name }}</span>
              <span class="task-desc">{{ task.description }}</span>
            </div>
            <span class="task-points">+{{ task.points }}</span>
          </div>
        </div>
        <button class="btn btn-cancel" :disabled="awarding" @click="showDialog = false">
          {{ awarding ? '发放中...' : '取消' }}
        </button>
      </div>
    </div>

    <!-- 新增学生弹窗 -->
    <div v-if="showCreateDialog" class="dialog-overlay" @click.self="closeCreateDialog">
      <div class="dialog card">
        <h3>新增学生</h3>
        <p class="dialog-hint">创建后学生可直接用以下账号登录</p>
        <div class="form-field">
          <label>用户名</label>
          <input v-model="newUsername" class="form-input" type="text" placeholder="2-12 个字符" maxlength="12" />
        </div>
        <div class="form-field">
          <label>初始密码</label>
          <input v-model="newPassword" class="form-input" type="text" placeholder="至少 4 位" />
        </div>
        <p v-if="createError" class="form-error">{{ createError }}</p>
        <div class="dialog-actions">
          <button class="btn btn-secondary" @click="closeCreateDialog">取消</button>
          <button class="btn btn-primary" :disabled="creating" @click="handleCreateStudent">
            {{ creating ? '创建中...' : '确认创建' }}
          </button>
        </div>
      </div>
    </div>

    <!-- 成功提示 -->
    <div v-if="toast" class="toast">{{ toast }}</div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useTeacherStore } from '../../stores/teacher'
import { useAuthStore } from '../../stores/auth'
import { useTasksStore } from '../../stores/tasks'
import type { Profile } from '../../stores/auth'
import type { Task } from '../../stores/tasks'

const router = useRouter()
const teacherStore = useTeacherStore()
const authStore = useAuthStore()
const tasksStore = useTasksStore()

const searchQuery = ref('')
const showDialog = ref(false)
const selectedStudent = ref<Profile | null>(null)
const selectedStudentIds = ref<string[]>([])
const awarding = ref(false)
const toast = ref('')

const visibleStudentIds = computed(() => teacherStore.students.map(student => student.id))
const allVisibleSelected = computed(() => (
  visibleStudentIds.value.length > 0
  && visibleStudentIds.value.every(id => selectedStudentIds.value.includes(id))
))
const someVisibleSelected = computed(() => (
  !allVisibleSelected.value
  && visibleStudentIds.value.some(id => selectedStudentIds.value.includes(id))
))
const awardDialogTitle = computed(() => selectedStudent.value
  ? `给 ${selectedStudent.value.username} 发积分`
  : `给已选 ${selectedStudentIds.value.length} 名学生发积分`)

// 新增学生状态
const showCreateDialog = ref(false)
const newUsername = ref('')
const newPassword = ref('')
const createError = ref('')
const creating = ref(false)

onMounted(async () => {
  await Promise.all([
    teacherStore.fetchStudents(),
    tasksStore.fetchTasks(),
  ])
})

function handleSearch() {
  teacherStore.fetchStudents(searchQuery.value || undefined)
}

function goDetail(id: string) {
  router.push(`/teacher/students/${id}`)
}

function openAwardDialog(student: Profile) {
  selectedStudent.value = student
  showDialog.value = true
}

function toggleStudent(studentId: string) {
  selectedStudentIds.value = selectedStudentIds.value.includes(studentId)
    ? selectedStudentIds.value.filter(id => id !== studentId)
    : [...selectedStudentIds.value, studentId]
}

function toggleSelectAll() {
  if (allVisibleSelected.value) {
    const visibleIds = new Set(visibleStudentIds.value)
    selectedStudentIds.value = selectedStudentIds.value.filter(id => !visibleIds.has(id))
  } else {
    selectedStudentIds.value = [...new Set([...selectedStudentIds.value, ...visibleStudentIds.value])]
  }
}

function openBatchAwardDialog() {
  if (selectedStudentIds.value.length === 0) return
  selectedStudent.value = null
  showDialog.value = true
}

async function confirmAward(task: Task) {
  const targetIds = selectedStudent.value ? [selectedStudent.value.id] : selectedStudentIds.value
  if (targetIds.length === 0 || awarding.value) return
  awarding.value = true
  const { error, awardedCount } = await tasksStore.awardPointsToStudents(targetIds, task.id)
  awarding.value = false
  if (!error) {
    showDialog.value = false
    const targetLabel = selectedStudent.value?.username || `${awardedCount} 名学生`
    toast.value = `已给 ${targetLabel} 发放 ${task.points} 积分`
    selectedStudentIds.value = selectedStudent.value
      ? selectedStudentIds.value
      : []
    selectedStudent.value = null
    await teacherStore.fetchStudents(searchQuery.value || undefined)
    setTimeout(() => { toast.value = '' }, 2500)
  } else {
    toast.value = awardedCount > 0
      ? `已发放 ${awardedCount} 人，后续发放失败：${error.message}`
      : `发放失败：${error.message}`
    setTimeout(() => { toast.value = '' }, 3500)
  }
}

async function handleDelete(student: Profile) {
  if (!confirm(`确定要删除学生「${student.username}」吗？该操作不可恢复，将同时删除其宠物和日记数据。`)) return
  const { error } = await teacherStore.deleteStudent(student.id)
  if (!error) {
    toast.value = `已删除学生「${student.username}」`
    setTimeout(() => { toast.value = '' }, 2500)
  }
}

function closeCreateDialog() {
  showCreateDialog.value = false
  newUsername.value = ''
  newPassword.value = ''
  createError.value = ''
}

async function handleCreateStudent() {
  createError.value = ''
  const uname = newUsername.value.trim()
  if (uname.length < 2 || uname.length > 12) {
    createError.value = '用户名需要 2-12 个字符'
    return
  }
  if (newPassword.value.length < 4) {
    createError.value = '密码至少 4 位'
    return
  }
  creating.value = true
  const { error } = await teacherStore.createStudent(uname, newPassword.value)
  creating.value = false
  if (error) {
    createError.value = error.message || '创建失败，请重试'
    return
  }
  toast.value = `已新增学生「${uname}」`
  setTimeout(() => { toast.value = '' }, 2500)
  closeCreateDialog()
}
</script>

<style scoped>
.teacher-page {
  padding-bottom: 80px;
}

.header-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  gap: 12px;
}

.header-row .page-title {
  margin: 0;
}

.class-label {
  margin: 4px 0 0;
  color: var(--color-text-muted);
  font-size: 0.8rem;
}

.form-field {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin-bottom: 12px;
}

.form-field label {
  font-size: 0.85rem;
  color: #666;
}

.form-error {
  color: var(--color-danger, #e74c3c);
  font-size: 0.8rem;
  margin: -4px 0 8px;
}

.dialog-actions {
  display: flex;
  gap: 8px;
  margin-top: 8px;
}

.dialog-actions .btn {
  flex: 1;
  padding: 10px 16px;
  font-size: 0.9rem;
}

.search-bar {
  margin-bottom: 16px;
}

.batch-toolbar {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 14px;
  margin-bottom: 12px;
}

.select-all {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  font-size: 0.85rem;
}

.select-all input,
.student-selector input {
  width: 17px;
  height: 17px;
  accent-color: var(--color-primary);
  cursor: pointer;
}

.selected-count {
  margin-left: auto;
  color: var(--color-text-muted);
  font-size: 0.82rem;
}

.batch-toolbar .btn:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

.loading-state, .empty-state {
  text-align: center;
  color: #999;
  padding: 32px;
}

.student-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.student-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 14px 16px;
}

.student-selector {
  display: flex;
  align-items: center;
  margin-right: 12px;
}

.student-info {
  display: flex;
  align-items: center;
  gap: 12px;
  cursor: pointer;
  flex: 1;
}

.student-avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: linear-gradient(135deg, var(--color-primary), var(--color-secondary));
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 1rem;
}

.student-meta {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.student-name {
  font-weight: 600;
  font-size: 0.95rem;
}

.student-points {
  font-size: 0.8rem;
  color: var(--color-success);
}

.btn-sm {
  padding: 6px 14px;
  font-size: 0.8rem;
  border-radius: 8px;
}

.btn-danger {
  background: var(--color-danger, #e74c3c);
  color: white;
  border: none;
}

.student-actions {
  display: flex;
  gap: 8px;
  flex-shrink: 0;
}

/* Dialog */
.dialog-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 200;
  padding: 20px;
}

.dialog {
  width: 100%;
  max-width: 400px;
  max-height: 70vh;
  overflow-y: auto;
  padding: 20px;
}

.dialog h3 {
  font-size: 1.1rem;
  margin-bottom: 8px;
}

.dialog-hint {
  color: #999;
  font-size: 0.85rem;
  margin-bottom: 12px;
}

.task-select-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 16px;
}

.task-select-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  border-radius: 8px;
  border: 1px solid #eee;
  cursor: pointer;
  transition: background 0.2s;
}

.task-select-item:hover {
  background: #f8f8ff;
  border-color: var(--color-primary);
}

.task-select-item.disabled {
  opacity: 0.55;
  pointer-events: none;
}

.task-select-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.task-name {
  font-weight: 600;
  font-size: 0.9rem;
}

.task-desc {
  font-size: 0.75rem;
  color: #999;
}

.task-points {
  font-weight: 700;
  color: var(--color-success);
  font-size: 1rem;
}

.btn-cancel {
  width: 100%;
  padding: 10px;
  border-radius: 8px;
  border: 1px solid #ddd;
  background: white;
  color: #666;
  cursor: pointer;
  font-size: 0.9rem;
}

.toast {
  position: fixed;
  top: 20px;
  left: 50%;
  transform: translateX(-50%);
  background: var(--color-success);
  color: white;
  padding: 10px 20px;
  border-radius: 8px;
  font-size: 0.9rem;
  z-index: 300;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}
</style>
