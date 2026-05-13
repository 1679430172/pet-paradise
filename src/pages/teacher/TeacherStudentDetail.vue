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
      <div v-else class="card empty-pet-card">
        <p class="empty-pet-text">该学生尚未创建宠物</p>
        <button class="btn btn-primary" @click="showAdoptDialog = true">🐾 为其领养宠物</button>
      </div>

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

    <!-- 领养宠物弹窗 -->
    <div v-if="showAdoptDialog" class="dialog-overlay" @click.self="closeAdoptDialog">
      <div class="dialog card">
        <h3>为 {{ studentProfile?.username }} 领养宠物</h3>

        <div class="adopt-section">
          <label class="adopt-label">选择种类</label>
          <div class="species-grid">
            <div
              v-for="s in PET_SPECIES"
              :key="s"
              class="species-card"
              :class="{ selected: adoptSpecies === s }"
              @click="adoptSpecies = s"
            >
              <span class="species-icon">{{ speciesIcons[s] }}</span>
              <span class="species-name">{{ PET_SPECIES_LABELS[s] }}</span>
            </div>
          </div>
        </div>

        <div class="adopt-section">
          <label class="adopt-label">选择颜色</label>
          <div class="color-grid">
            <div
              v-for="c in PET_COLORS"
              :key="c"
              class="color-dot"
              :class="{ selected: adoptColor === c }"
              :style="{ background: c }"
              @click="adoptColor = c"
            />
          </div>
        </div>

        <div class="adopt-section">
          <label class="adopt-label">宠物名字</label>
          <input v-model="adoptName" class="form-input" type="text" placeholder="输入宠物的名字" maxlength="10" />
        </div>

        <p v-if="adoptError" class="form-error">{{ adoptError }}</p>

        <div class="dialog-actions">
          <button class="btn-cancel" @click="closeAdoptDialog">取消</button>
          <button class="btn btn-primary" :disabled="!adoptSpecies || !adoptName || adopting" @click="handleAdopt">
            {{ adopting ? '领养中...' : '确认领养' }}
          </button>
        </div>
      </div>
    </div>

    <div v-if="toast" class="toast">{{ toast }}</div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useTeacherStore } from '../../stores/teacher'
import { PET_SPECIES, PET_SPECIES_LABELS, PET_COLORS } from '../../lib/constants'

const route = useRoute()
const router = useRouter()
const teacherStore = useTeacherStore()

const loading = ref(true)
const studentProfile = ref<any>(null)
const petInfo = ref<any>(null)
const completions = ref<any[]>([])

// 领养宠物状态
const showAdoptDialog = ref(false)
const adoptSpecies = ref('')
const adoptColor = ref(PET_COLORS[0])
const adoptName = ref('')
const adoptError = ref('')
const adopting = ref(false)
const toast = ref('')

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

function closeAdoptDialog() {
  showAdoptDialog.value = false
  adoptSpecies.value = ''
  adoptColor.value = PET_COLORS[0]
  adoptName.value = ''
  adoptError.value = ''
}

async function handleAdopt() {
  if (!studentProfile.value) return
  adoptError.value = ''
  adopting.value = true
  const { data, error } = await teacherStore.adoptPetForStudent(
    studentProfile.value.id,
    adoptName.value.trim(),
    adoptSpecies.value,
    adoptColor.value,
  )
  adopting.value = false
  if (error) {
    adoptError.value = error.message || '领养失败，请重试'
    return
  }
  petInfo.value = data
  toast.value = `已为 ${studentProfile.value.username} 领养宠物`
  setTimeout(() => { toast.value = '' }, 2500)
  closeAdoptDialog()
}
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

.empty-pet-card {
  text-align: center;
  padding: 20px 16px;
  margin-bottom: 16px;
  display: flex;
  flex-direction: column;
  gap: 12px;
  align-items: center;
}

.empty-pet-text {
  color: #999;
  font-size: 0.9rem;
}

.empty-pet-card .btn {
  padding: 10px 20px;
}

/* Adopt dialog */
.dialog-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
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
  max-height: 85vh;
  overflow-y: auto;
  padding: 20px;
}

.dialog h3 {
  font-size: 1.1rem;
  margin-bottom: 12px;
}

.adopt-section {
  margin-bottom: 14px;
}

.adopt-label {
  display: block;
  font-size: 0.85rem;
  color: #666;
  margin-bottom: 6px;
}

.species-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
}

.species-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 10px 6px;
  background: white;
  border: 2px solid var(--color-border, #eee);
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
}

.species-card.selected {
  border-color: var(--color-primary);
  background: #FFF0F5;
}

.species-icon {
  font-size: 1.6rem;
}

.species-name {
  font-size: 0.75rem;
  color: #666;
}

.color-grid {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.color-dot {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  cursor: pointer;
  border: 3px solid transparent;
  transition: all 0.2s;
}

.color-dot.selected {
  border-color: #333;
  transform: scale(1.15);
}

.form-error {
  color: var(--color-danger, #e74c3c);
  font-size: 0.8rem;
  margin: 4px 0 8px;
}

.dialog-actions {
  display: flex;
  gap: 8px;
  margin-top: 8px;
}

.btn-cancel {
  flex: 1;
  padding: 10px;
  border-radius: 8px;
  border: 1px solid #ddd;
  background: white;
  color: #666;
  cursor: pointer;
  font-size: 0.9rem;
}

.dialog-actions .btn {
  flex: 1;
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
