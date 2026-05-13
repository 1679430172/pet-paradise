<template>
  <div class="page teacher-page">
    <h1 class="page-title">学生宠物</h1>

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
    <div v-else-if="teacherStore.studentsWithPets.length === 0" class="empty-state">暂无学生</div>
    <div v-else class="pet-list">
      <div
        v-for="s in teacherStore.studentsWithPets"
        :key="s.id"
        class="pet-card card"
      >
        <template v-if="s.pet">
          <span class="level-badge">Lv.{{ s.pet.level }}</span>
          <div class="pet-hero" :style="{ background: s.pet.appearance?.color || '#FFB6C1' }">
            <span class="pet-hero-icon">{{ speciesIcon(s.pet.species) }}</span>
          </div>
          <h2 class="pet-name">{{ s.username }}</h2>
          <div class="pet-sub">
            <span class="pet-sub-name">{{ s.pet.name }}</span>
            <span class="pet-sub-dot">·</span>
            <span class="pet-sub-points">{{ s.points }}分</span>
          </div>

          <div class="pet-stats">
            <div class="pet-stat">
              <span class="stat-label">🍖</span>
              <div class="stat-bar"><div class="stat-fill" :style="{ width: (s.pet.hunger || 0) + '%' }"></div></div>
            </div>
            <div class="pet-stat">
              <span class="stat-label">🎾</span>
              <div class="stat-bar"><div class="stat-fill happy" :style="{ width: (s.pet.happiness || 0) + '%' }"></div></div>
            </div>
            <div class="pet-stat">
              <span class="stat-label">🛁</span>
              <div class="stat-bar"><div class="stat-fill clean" :style="{ width: (s.pet.cleanliness || 0) + '%' }"></div></div>
            </div>
          </div>

          <div class="action-row">
            <button
              class="btn-action"
              :disabled="busyId === s.id || s.points < pointsStore.actionCosts.feed"
              @click="handleAction(s, 'feed')"
              :title="`喂食 -${pointsStore.actionCosts.feed}`"
            >
              <span class="action-icon">🍖</span>
              <span class="cost">-{{ pointsStore.actionCosts.feed }}</span>
            </button>
            <button
              class="btn-action"
              :disabled="busyId === s.id || s.points < pointsStore.actionCosts.play"
              @click="handleAction(s, 'play')"
              :title="`玩耍 -${pointsStore.actionCosts.play}`"
            >
              <span class="action-icon">🎾</span>
              <span class="cost">-{{ pointsStore.actionCosts.play }}</span>
            </button>
            <button
              class="btn-action"
              :disabled="busyId === s.id || s.points < pointsStore.actionCosts.clean"
              @click="handleAction(s, 'clean')"
              :title="`清洁 -${pointsStore.actionCosts.clean}`"
            >
              <span class="action-icon">🛁</span>
              <span class="cost">-{{ pointsStore.actionCosts.clean }}</span>
            </button>
          </div>
        </template>

        <template v-else>
          <div class="pet-hero empty-hero">
            <span class="pet-hero-icon empty">🥚</span>
          </div>
          <h2 class="pet-name">{{ s.username }}</h2>
          <div class="pet-sub">
            <span class="pet-sub-muted">未领养宠物</span>
            <span class="pet-sub-dot">·</span>
            <span class="pet-sub-points">{{ s.points }}分</span>
          </div>
          <button class="btn btn-primary adopt-btn" @click="openAdoptDialog(s)">🐾 领养</button>
        </template>
      </div>
    </div>

    <!-- 领养弹窗 -->
    <div v-if="showAdoptDialog" class="dialog-overlay" @click.self="closeAdoptDialog">
      <div class="dialog card">
        <h3>为 {{ adoptTarget?.username }} 领养宠物</h3>

        <div class="adopt-section">
          <label class="adopt-label">选择种类</label>
          <div class="species-grid">
            <div
              v-for="sp in PET_SPECIES"
              :key="sp"
              class="species-card"
              :class="{ selected: adoptSpecies === sp }"
              @click="adoptSpecies = sp"
            >
              <span class="species-icon">{{ speciesIcons[sp] }}</span>
              <span class="species-name">{{ PET_SPECIES_LABELS[sp] }}</span>
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
import { useTeacherStore, type StudentWithPet } from '../../stores/teacher'
import { usePointsStore } from '../../stores/points'
import { PET_SPECIES, PET_SPECIES_LABELS, PET_COLORS } from '../../lib/constants'

const teacherStore = useTeacherStore()
const pointsStore = usePointsStore()

const searchQuery = ref('')
const busyId = ref<string | null>(null)
const toast = ref('')

// 领养弹窗
const showAdoptDialog = ref(false)
const adoptTarget = ref<StudentWithPet | null>(null)
const adoptSpecies = ref('')
const adoptColor = ref(PET_COLORS[0])
const adoptName = ref('')
const adoptError = ref('')
const adopting = ref(false)

const speciesIcons: Record<string, string> = {
  cat: '🐱', dog: '🐶', rabbit: '🐰', hamster: '🐹', bird: '🐦', turtle: '🐢',
}

function speciesIcon(sp: string) {
  return speciesIcons[sp] || '🐾'
}

onMounted(async () => {
  await Promise.all([
    teacherStore.fetchStudentsWithPets(),
    pointsStore.fetchActionCosts(),
  ])
})

function handleSearch() {
  teacherStore.fetchStudentsWithPets(searchQuery.value || undefined)
}

function showToast(msg: string) {
  toast.value = msg
  setTimeout(() => { toast.value = '' }, 2500)
}

async function handleAction(s: StudentWithPet, action: 'feed' | 'play' | 'clean') {
  if (!s.pet || !s.pet.id) return
  busyId.value = s.id
  const result = await teacherStore.performActionForStudent(s.id, s.pet.id, action)
  busyId.value = null
  if (result.error) {
    showToast(result.error.message || '操作失败')
    return
  }
  const actionLabel = action === 'feed' ? '喂食' : action === 'play' ? '玩耍' : '清洁'
  const levelMsg = result.leveledUp ? `，升到 ${result.newLevel} 级！` : ''
  showToast(`已为 ${s.username} 的宠物${actionLabel}（-${result.cost} 积分）${levelMsg}`)
}

function openAdoptDialog(s: StudentWithPet) {
  adoptTarget.value = s
  adoptSpecies.value = ''
  adoptColor.value = PET_COLORS[0]
  adoptName.value = ''
  adoptError.value = ''
  showAdoptDialog.value = true
}

function closeAdoptDialog() {
  showAdoptDialog.value = false
  adoptTarget.value = null
}

async function handleAdopt() {
  if (!adoptTarget.value) return
  adoptError.value = ''
  adopting.value = true
  const { data, error } = await teacherStore.adoptPetForStudent(
    adoptTarget.value.id,
    adoptName.value.trim(),
    adoptSpecies.value,
    adoptColor.value,
  )
  adopting.value = false
  if (error) {
    adoptError.value = error.message || '领养失败，请重试'
    return
  }
  // 回填本地列表
  const target = teacherStore.studentsWithPets.find(x => x.id === adoptTarget.value!.id)
  if (target && data) {
    target.pet = data
  }
  showToast(`已为 ${adoptTarget.value.username} 领养宠物`)
  closeAdoptDialog()
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

.pet-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 12px;
}

.pet-card {
  position: relative;
  padding: 16px 10px 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  background: linear-gradient(180deg, #fffafc 0%, #ffffff 100%);
  box-shadow: 0 4px 14px rgba(255, 107, 157, 0.08);
  transition: transform 0.2s, box-shadow 0.2s;
}

.pet-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(255, 107, 157, 0.15);
}

.level-badge {
  position: absolute;
  top: 8px;
  right: 8px;
  background: linear-gradient(135deg, #FFD700, #FFA500);
  color: white;
  padding: 2px 8px;
  border-radius: 16px;
  font-size: 0.68rem;
  font-weight: 700;
  box-shadow: 0 2px 6px rgba(255, 165, 0, 0.3);
}

.pet-hero {
  width: 68px;
  height: 68px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
  border: 3px solid #fff;
}

.pet-hero.empty-hero {
  background: #f5f5f7;
  border: 2px dashed #ddd;
  box-shadow: none;
}

.pet-hero-icon {
  font-size: 2.2rem;
  line-height: 1;
}

.pet-hero-icon.empty {
  font-size: 1.8rem;
  opacity: 0.6;
}

.pet-name {
  font-size: 1.05rem;
  font-weight: 700;
  color: var(--color-text);
  margin: 0;
  text-align: center;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pet-sub {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 0.72rem;
  color: #888;
  max-width: 100%;
  overflow: hidden;
  white-space: nowrap;
}

.pet-sub-name {
  color: #555;
  font-weight: 600;
  max-width: 70px;
  overflow: hidden;
  text-overflow: ellipsis;
}

.pet-sub-muted {
  color: #bbb;
  font-style: italic;
}

.pet-sub-dot {
  color: #ccc;
}

.pet-sub-points {
  color: var(--color-success);
  font-weight: 600;
}

.pet-stats {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 6px 8px;
  background: #faf9fb;
  border-radius: 8px;
  margin-top: 2px;
}

.pet-stat {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 0.75rem;
}

.stat-label {
  width: 16px;
  flex-shrink: 0;
  text-align: center;
}

.stat-bar {
  flex: 1;
  height: 6px;
  background: #ececf2;
  border-radius: 3px;
  overflow: hidden;
}

.stat-fill {
  height: 100%;
  background: var(--color-primary);
  border-radius: 3px;
  transition: width 0.3s;
}

.stat-fill.happy { background: #F59E0B; }
.stat-fill.clean { background: #06B6D4; }

.action-row {
  width: 100%;
  display: flex;
  gap: 4px;
  margin-top: 2px;
}

.btn-action {
  flex: 1;
  padding: 6px 2px;
  border-radius: 8px;
  border: 1.5px solid #f0e6ea;
  background: white;
  color: #444;
  cursor: pointer;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1px;
  transition: all 0.2s;
}

.btn-action:hover:not(:disabled) {
  background: #fff0f5;
  border-color: var(--color-primary);
  transform: translateY(-1px);
}

.btn-action:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.action-icon {
  font-size: 1rem;
}

.btn-action .cost {
  font-size: 0.65rem;
  color: var(--color-danger, #e74c3c);
  font-weight: 600;
}

.adopt-btn {
  margin-top: 6px;
  padding: 8px 18px;
  font-size: 0.82rem;
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
  font-size: 0.88rem;
  z-index: 300;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  max-width: 80vw;
  text-align: center;
}
</style>
