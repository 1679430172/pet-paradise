<template>
  <div class="page teacher-page">
    <div class="page-header">
      <button class="btn-back" @click="router.back()">← 返回</button>
      <h1 class="page-title">学生详情</h1>
    </div>

    <div v-if="loading" class="loading-state">加载中...</div>
    <template v-else-if="studentProfile">
      <div class="profile-section card">
        <div class="student-avatar-lg">{{ studentProfile.username.charAt(0) }}</div>
        <h2>{{ studentProfile.username }}</h2>
        <div class="points-badge">{{ studentProfile.points }} 积分</div>
      </div>

      <div v-if="petInfo" class="pet-section card">
        <h3>宠物信息</h3>
        <div class="pet-detail">
          <span class="pet-species">{{ speciesIcon(petInfo.species) }} {{ petInfo.name }}</span>
          <span class="pet-level">Lv.{{ petInfo.level }}</span>
        </div>
        <div class="pet-stats">
          <div class="pet-stat">
            <span>饱食</span>
            <div class="stat-bar"><div class="stat-fill" :style="{ width: petInfo.hunger + '%' }"></div></div>
          </div>
          <div class="pet-stat">
            <span>快乐</span>
            <div class="stat-bar"><div class="stat-fill happy" :style="{ width: petInfo.happiness + '%' }"></div></div>
          </div>
          <div class="pet-stat">
            <span>清洁</span>
            <div class="stat-bar"><div class="stat-fill clean" :style="{ width: petInfo.cleanliness + '%' }"></div></div>
          </div>
        </div>
      </div>
      <div v-else class="card empty-state">该学生尚未创建宠物</div>

      <div class="history-section">
        <h3>积分记录</h3>
        <div v-if="completions.length === 0" class="empty-state">暂无记录</div>
        <div v-else class="completion-list">
          <div v-for="c in completions" :key="c.id" class="completion-item card">
            <div class="completion-info">
              <span class="completion-task">{{ c.task?.name || '任务' }}</span>
              <span class="completion-time">{{ formatTime(c.created_at) }}</span>
            </div>
            <span class="completion-points">+{{ c.points }}</span>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useTeacherStore } from '../../stores/teacher'

const route = useRoute()
const router = useRouter()
const teacherStore = useTeacherStore()

const loading = ref(true)
const studentProfile = ref<any>(null)
const petInfo = ref<any>(null)
const completions = ref<any[]>([])

const speciesIcons: Record<string, string> = {
  cat: '🐱', dog: '🐶', rabbit: '🐰', hamster: '🐹', bird: '🐦', turtle: '🐢'
}

function speciesIcon(species: string) {
  return speciesIcons[species] || '🐾'
}

function formatTime(dateStr: string) {
  const d = new Date(dateStr)
  return `${d.getMonth() + 1}/${d.getDate()} ${d.getHours()}:${String(d.getMinutes()).padStart(2, '0')}`
}

onMounted(async () => {
  const id = route.params.id as string
  const result = await teacherStore.fetchStudentDetail(id)
  studentProfile.value = result.profile
  petInfo.value = result.pet
  completions.value = result.completions || []
  loading.value = false
})
</script>

<style scoped>
.teacher-page {
  padding-bottom: 80px;
}

.page-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 20px;
}

.btn-back {
  background: none;
  border: none;
  color: var(--color-primary);
  font-size: 0.9rem;
  cursor: pointer;
}

.loading-state, .empty-state {
  text-align: center;
  color: #999;
  padding: 24px;
}

.profile-section {
  text-align: center;
  padding: 24px;
  margin-bottom: 16px;
}

.student-avatar-lg {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  background: linear-gradient(135deg, var(--color-primary), var(--color-secondary));
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.5rem;
  font-weight: 700;
  margin: 0 auto 12px;
}

.profile-section h2 {
  margin-bottom: 8px;
}

.points-badge {
  display: inline-block;
  background: linear-gradient(135deg, #FFD700, #FFA500);
  color: white;
  padding: 4px 14px;
  border-radius: 20px;
  font-weight: 600;
  font-size: 0.9rem;
}

.pet-section {
  padding: 16px;
  margin-bottom: 16px;
}

.pet-section h3 {
  margin-bottom: 12px;
  font-size: 0.95rem;
}

.pet-detail {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}

.pet-species {
  font-size: 1rem;
  font-weight: 600;
}

.pet-level {
  background: var(--color-primary);
  color: white;
  padding: 2px 10px;
  border-radius: 12px;
  font-size: 0.8rem;
}

.pet-stats {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.pet-stat {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 0.8rem;
  color: #666;
}

.pet-stat span {
  width: 36px;
}

.stat-bar {
  flex: 1;
  height: 8px;
  background: #eee;
  border-radius: 4px;
  overflow: hidden;
}

.stat-fill {
  height: 100%;
  background: var(--color-primary);
  border-radius: 4px;
  transition: width 0.3s;
}

.stat-fill.happy { background: #F59E0B; }
.stat-fill.clean { background: #06B6D4; }

.history-section {
  margin-top: 16px;
}

.history-section h3 {
  font-size: 0.95rem;
  margin-bottom: 12px;
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
  padding: 12px 14px;
}

.completion-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.completion-task {
  font-weight: 500;
  font-size: 0.9rem;
}

.completion-time {
  font-size: 0.75rem;
  color: #999;
}

.completion-points {
  font-weight: 700;
  color: var(--color-success);
}
</style>
