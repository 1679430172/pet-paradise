<template>
  <div class="page teacher-page">
    <h1 class="page-title">学生管理</h1>

    <div class="search-bar">
      <input
        v-model="searchQuery"
        type="text"
        class="form-input"
        placeholder="搜索学生..."
        @input="handleSearch"
      />
    </div>

    <div v-if="teacherStore.loading" class="loading-state">加载中...</div>
    <div v-else-if="teacherStore.students.length === 0" class="empty-state">暂无学生</div>
    <div v-else class="student-list">
      <div
        v-for="student in teacherStore.students"
        :key="student.id"
        class="student-card card"
      >
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
        <h3>给 {{ selectedStudent?.username }} 发积分</h3>
        <p class="dialog-hint">选择已完成的任务：</p>
        <div v-if="tasksStore.tasks.length === 0" class="empty-state">暂无任务，请先创建任务</div>
        <div v-else class="task-select-list">
          <div
            v-for="task in tasksStore.tasks"
            :key="task.id"
            class="task-select-item"
            @click="confirmAward(task)"
          >
            <div class="task-select-info">
              <span class="task-name">{{ task.name }}</span>
              <span class="task-desc">{{ task.description }}</span>
            </div>
            <span class="task-points">+{{ task.points }}</span>
          </div>
        </div>
        <button class="btn btn-cancel" @click="showDialog = false">取消</button>
      </div>
    </div>

    <!-- 成功提示 -->
    <div v-if="toast" class="toast">{{ toast }}</div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useTeacherStore } from '../../stores/teacher'
import { useTasksStore } from '../../stores/tasks'
import type { Profile } from '../../stores/auth'
import type { Task } from '../../stores/tasks'

const router = useRouter()
const teacherStore = useTeacherStore()
const tasksStore = useTasksStore()

const searchQuery = ref('')
const showDialog = ref(false)
const selectedStudent = ref<Profile | null>(null)
const toast = ref('')

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

async function confirmAward(task: Task) {
  if (!selectedStudent.value) return
  const { error } = await tasksStore.awardPoints(selectedStudent.value.id, task.id)
  showDialog.value = false
  if (!error) {
    toast.value = `已给 ${selectedStudent.value.username} 发放 ${task.points} 积分`
    teacherStore.fetchStudents(searchQuery.value || undefined)
    setTimeout(() => { toast.value = '' }, 2500)
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
</script>

<style scoped>
.teacher-page {
  padding-bottom: 80px;
}

.search-bar {
  margin-bottom: 16px;
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
