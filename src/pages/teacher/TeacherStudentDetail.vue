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
        <div class="student-name-row">
          <h2>{{ studentProfile.username }}</h2>
          <button class="rename-student-btn" type="button" title="修改学生名字" @click="openRenameDialog">✎</button>
        </div>
        <div class="points-badge">{{ studentProfile.points }} 积分</div>
      </div>

      <div v-if="pets.length > 0" class="pet-section card">
        <h3>宠物列表（{{ pets.length }}）</h3>
        <div v-for="p in pets" :key="p.id" class="pet-item">
          <PetAvatar
            :species="p.species"
            :level="p.level"
            :size="56"
            show-stage
          />
          <div class="pet-item-info">
            <div class="pet-detail">
              <span class="pet-species">{{ p.name }}</span>
              <span class="pet-level" :class="{ maxed: p.level >= MAX_LEVEL }">Lv.{{ p.level }}</span>
            </div>
            <div class="pet-stats">
              <div class="pet-stat">
                <span>饱食</span>
                <div class="stat-bar"><div class="stat-fill" :style="{ width: (p.hunger || 0) + '%' }"></div></div>
              </div>
            </div>
          </div>
        </div>
        <button
          v-if="canAdoptNew"
          class="btn btn-primary adopt-more-btn"
          @click="showAdoptDialog = true"
        >🐾 领养新宠物</button>
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

    <!-- 修改学生名字弹窗 -->
    <div v-if="showRenameDialog" class="dialog-overlay" @click.self="closeRenameDialog">
      <div class="dialog card">
        <h3>修改学生名字</h3>
        <p class="rename-hint">修改后，学生需要使用新名字登录。</p>
        <div class="rename-field">
          <label for="rename-student-input">新名字</label>
          <input
            id="rename-student-input"
            ref="renameInput"
            v-model="renameUsername"
            class="form-input"
            type="text"
            maxlength="12"
            placeholder="输入学生的新名字"
            @keyup.enter="handleRename"
          />
          <span class="name-count">{{ renameUsername.trim().length }}/12</span>
        </div>
        <p v-if="renameError" class="form-error">{{ renameError }}</p>
        <div class="dialog-actions">
          <button class="btn-cancel" :disabled="renaming" @click="closeRenameDialog">取消</button>
          <button class="btn btn-primary" :disabled="!renameUsername.trim() || renaming" @click="handleRename">
            {{ renaming ? '保存中...' : '保存名字' }}
          </button>
        </div>
      </div>
    </div>

    <!-- 领养宠物弹窗 -->
    <div v-if="showAdoptDialog" class="dialog-overlay" @click.self="closeAdoptDialog">
      <div class="dialog card">
        <h3>为 {{ studentProfile?.username }} 领养宠物</h3>

        <PetAdoptionFields v-model:species="adoptSpecies" v-model:color="adoptColor" v-model:name="adoptName" />

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
import { ref, computed, nextTick, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useTeacherStore, type TeacherPet } from '../../stores/teacher'
import { PET_COLORS, MAX_LEVEL } from '../../lib/constants'
import PetAvatar from '../../components/pet/PetAvatar.vue'
import PetAdoptionFields from '../../components/pet/PetAdoptionFields.vue'

const route = useRoute()
const router = useRouter()
const teacherStore = useTeacherStore()

const loading = ref(true)
const studentProfile = ref<any>(null)
const pets = ref<TeacherPet[]>([])
const completions = ref<any[]>([])

// 领养宠物状态
const showAdoptDialog = ref(false)
const adoptSpecies = ref('')
const adoptColor = ref(PET_COLORS[0])
const adoptName = ref('')
const adoptError = ref('')
const adopting = ref(false)
const toast = ref('')

// 修改学生名字状态
const showRenameDialog = ref(false)
const renameUsername = ref('')
const renameError = ref('')
const renaming = ref(false)
const renameInput = ref<HTMLInputElement | null>(null)

const canAdoptNew = computed(() => {
  return pets.value.length === 0 || pets.value.every(p => (p.level || 1) >= MAX_LEVEL)
})

function formatTime(dateStr: string) {
  const d = new Date(dateStr)
  return `${d.getMonth() + 1}/${d.getDate()} ${d.getHours()}:${String(d.getMinutes()).padStart(2, '0')}`
}

onMounted(async () => {
  const id = route.params.id as string
  const result = await teacherStore.fetchStudentDetail(id)
  studentProfile.value = result.profile
  pets.value = result.pets || []
  completions.value = result.completions || []
  loading.value = false
})

function openRenameDialog() {
  if (!studentProfile.value) return
  renameUsername.value = studentProfile.value.username
  renameError.value = ''
  showRenameDialog.value = true
  nextTick(() => {
    renameInput.value?.focus()
    renameInput.value?.select()
  })
}

function closeRenameDialog() {
  if (renaming.value) return
  showRenameDialog.value = false
  renameUsername.value = ''
  renameError.value = ''
}

async function handleRename() {
  if (!studentProfile.value || renaming.value) return
  const newUsername = renameUsername.value.trim()
  if (newUsername.length < 2 || newUsername.length > 12) {
    renameError.value = '用户名需要 2-12 个字符'
    return
  }
  if (newUsername === studentProfile.value.username) {
    closeRenameDialog()
    return
  }

  renaming.value = true
  renameError.value = ''
  const { error, username } = await teacherStore.renameStudent(studentProfile.value.id, newUsername)
  renaming.value = false
  if (error) {
    renameError.value = error.message || '修改失败，请重试'
    return
  }
  studentProfile.value.username = username
  toast.value = `学生名字已修改为「${username}」`
  setTimeout(() => { toast.value = '' }, 2500)
  closeRenameDialog()
}

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
  if (data) pets.value = [...pets.value, data]
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
  margin: 0;
}

.student-name-row {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 6px;
  margin-bottom: 8px;
}

.rename-student-btn {
  width: 26px;
  height: 26px;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: #fff0f5;
  color: var(--color-primary);
  cursor: pointer;
  font-size: 0.82rem;
}

.rename-student-btn:hover,
.rename-student-btn:focus-visible {
  background: #ffe0ec;
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

.pet-item {
  display: flex;
  gap: 12px;
  padding: 10px 0;
  border-bottom: 1px dashed #eee;
}

.pet-item:last-of-type {
  border-bottom: none;
}

.pet-item-info {
  flex: 1;
  min-width: 0;
}

.adopt-more-btn {
  margin-top: 10px;
  width: 100%;
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

.pet-level.maxed {
  background: linear-gradient(135deg, #A78BFA, #6366F1);
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

.rename-hint {
  margin: -4px 0 14px;
  color: var(--color-text-muted);
  font-size: 0.82rem;
}

.rename-field {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 7px;
  margin-bottom: 10px;
}

.rename-field label {
  color: #666;
  font-size: 0.85rem;
}

.rename-field .form-input {
  padding-right: 54px;
}

.name-count {
  position: absolute;
  right: 12px;
  bottom: 12px;
  color: var(--color-text-muted);
  font-size: 0.72rem;
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
