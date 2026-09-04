<template>
  <div class="page teacher-page pets-page" :class="{ 'classroom-mode': classroomMode, 'classroom-compact': classroomMode && classroomDensity === 180 }" :style="classroomMode ? { '--classroom-card-width': classroomDensity + 'px' } : {}">
    <header class="pets-toolbar">
    <div class="page-title-row">
      <div><p v-if="classroomMode" class="classroom-eyebrow">{{ authStore.user?.class_name || '我们的班级' }} · {{ teacherStore.studentsWithPets.length }} 位同学</p>
        <h1 class="page-title">{{ classroomMode ? '今天，也在一起长大' : '学生宠物' }}</h1></div>
      <div class="page-actions">
        <button v-if="!classroomMode" class="btn btn-secondary" @click="enterClassroom">课堂大屏</button>
        <template v-else>
          <select v-model="classroomDensity" class="form-input density-select" aria-label="卡片大小"><option :value="180">紧凑</option><option :value="230">标准</option><option :value="300">大字</option></select>
          <button class="btn btn-secondary" @click="toggleFullscreen">{{ fullscreen ? '退出全屏' : '全屏显示' }}</button>
          <button class="btn btn-secondary" @click="exitClassroom">返回普通视图</button>
        </template>
      <button v-if="!classroomMode" class="btn btn-primary batch-entry-btn" :disabled="batchPetOptions.length === 0 || awarding || !!busyKey || batchFeeding" @click="openBatchFeedDialog">批量投喂</button>
      </div>
    </div>

    <div class="search-bar">
      <input
        v-model="searchQuery"
        type="text"
        class="form-input"
        placeholder="搜索学生..."
        :disabled="awarding"
        @input="handleSearch"
      />
      <label class="sort-control">
        <span>排序</span>
        <select v-model="sortBy" class="form-input sort-select">
          <option value="default">默认排序</option>
          <option value="name-asc">学生姓名：正序</option>
          <option value="name-desc">学生姓名：倒序</option>
          <option value="level-desc">宠物等级：从高到低</option>
          <option value="level-asc">宠物等级：从低到高</option>
          <option value="hunger-asc">饥饿值：最饿优先</option>
          <option value="hunger-desc">饥饿值：最饱优先</option>
        </select>
      </label>
    </div>
    <p v-if="sortBy.startsWith('level') || sortBy.startsWith('hunger')" class="sort-hint">
      按当前显示的宠物排序，未领养的学生排在最后。饱食度越低，宠物越饿。
    </p>

    <section v-if="classroomMode" :class="{ 'has-selection': awardStudentIds.length > 0 }" class="classroom-award-bar" aria-label="课堂快捷奖励">
      <label class="classroom-select-all"><input type="checkbox" :checked="allAwardSelected" :disabled="awarding" @change="toggleAwardAll" />全选筛选结果</label>
      <span class="award-count">已选 <strong>{{ awardStudentIds.length }}</strong> 人</span>
      <select v-model="awardTaskId" class="form-input classroom-task" :disabled="awarding" aria-label="选择奖励任务">
        <option value="">选择奖励任务</option><option v-for="task in tasksStore.tasks" :key="task.id" :value="task.id">{{ task.name }} +{{ task.points }}分</option>
      </select>
      <button class="btn btn-primary" :disabled="!awardTaskId || !awardStudentIds.length || awarding || !!busyKey || batchFeeding" @click="awardSelected">{{ awarding ? '正在发放...' : '发放奖励' }}</button>
      <button v-if="awardStudentIds.length" class="clear-selection" :disabled="awarding" @click="awardStudentIds = []">清空</button>
      <p v-if="!tasksStore.tasks.length" class="classroom-task-hint">请先在任务管理中创建奖励任务。</p>
    </section>
    </header>
    <div class="pets-content">
    <div v-if="classroomNotice && classroomMode" class="classroom-notice" role="status">{{ classroomNotice }}</div>
    <ul v-if="classroomMode && awardFailures.length" class="classroom-failures"><li v-for="failure in awardFailures" :key="failure.studentId">{{ teacherStore.studentsWithPets.find(s => s.id === failure.studentId)?.username || '学生' }}：{{ failure.message }}</li></ul>
    <div v-if="initialLoading" class="loading-state">加载中...</div>
    <div v-else-if="sortedStudents.length === 0" class="empty-state">暂无匹配的学生</div>
    <div v-else class="pet-list">
      <div
        v-for="s in sortedStudents"
        :key="s.id"
        class="pet-card card"
        :class="{ 'empty-adopt-card': !activePet(s), 'award-selected': classroomMode && awardStudentIds.includes(s.id), 'award-bounce': !!awardBubbles[s.id] }"
        :style="cardStyle(s)"
      >
        <label v-if="classroomMode" class="classroom-student-select"><input type="checkbox" :checked="awardStudentIds.includes(s.id)" :disabled="awarding" @change="toggleAwardStudent(s.id)" :aria-label="`选择 ${s.username}`" /><span class="card-selection-mark" aria-hidden="true">{{ awardStudentIds.includes(s.id) ? '✓' : '' }}</span></label>
        <Transition name="speech-pop"><div v-if="awardBubbles[s.id]" class="award-bubble" role="status">{{ awardBubbles[s.id] }}</div></Transition>
        <!-- 左上角：积分 -->
        <span class="points-badge">{{ s.points }}分</span>

        <!-- 有活跃宠物 -->
        <template v-if="activePet(s)">
          <!-- 顶部中间：宠物名字（小字） -->
          <div class="pet-name-top">
            <span>{{ activePet(s)!.name }}</span>
            <button
              type="button"
              class="rename-pet-btn"
              title="修改宠物名字"
              :aria-label="`修改宠物 ${activePet(s)!.name} 的名字`"
              @click="openRenameDialog(s, activePet(s)!)"
            >✎</button>
          </div>

          <!-- 右上角：等级 -->
          <span
            class="level-badge"
            :class="{ 'max-badge': activePet(s)!.level >= MAX_LEVEL }"
          >Lv.{{ activePet(s)!.level }}</span>

          <div
            class="pet-stage"
            @mouseenter="showHoverReply(activePet(s)!)"
            @mouseleave="hideHoverReply"
          >
            <button
              v-if="s.pets.length > 1"
              class="nav-arrow left"
              type="button"
              title="上一只"
              aria-label="上一只宠物"
              @click="prev(s)"
            >‹</button>
            <PetAvatar
              :species="activePet(s)!.species"
              :level="activePet(s)!.level"
              :size="classroomMode ? (classroomDensity === 180 ? 110 : 140) : 160"
              show-stage
            />
            <Transition name="speech-pop">
              <div v-if="petReplies[activePet(s)!.id] || hoverPetId === activePet(s)!.id" class="pet-speech">
                {{ petReplies[activePet(s)!.id] || hoverPetReply }}
              </div>
            </Transition>
            <button
              v-if="s.pets.length > 1"
              class="nav-arrow right"
              type="button"
              title="下一只"
              aria-label="下一只宠物"
              @click="next(s)"
            >›</button>
          </div>
          <!-- 主标题：学生姓名 -->
          <h2 class="pet-name">{{ s.username }}</h2>

          <div class="pet-stats">
            <div class="pet-stat">
              <span class="stat-label">🍖</span>
              <div class="stat-bar"><div class="stat-fill" :style="{ width: (activePet(s)!.hunger || 0) + '%' }"></div></div>
            </div>
            <div class="pet-stat xp-stat" :title="xpLabel(activePet(s)!)">
              <span class="stat-label">✨</span>
              <div class="stat-bar"><div class="stat-fill xp-fill" :style="{ width: xpProgress(activePet(s)!) + '%' }"></div></div>
              <span class="stat-value">{{ xpLabel(activePet(s)!) }}</span>
            </div>
          </div>

          <div class="action-row">
            <button
              class="btn-action"
              :disabled="!!busyKey || batchFeeding || awarding || s.points < pointsStore.actionCosts.basic"
              @click="handleAction(s, activePet(s)!, 'basic')"
              :title="`普通粮 -${pointsStore.actionCosts.basic}`"
            >
              <span class="action-icon">🍖</span>
              <span class="cost">-{{ pointsStore.actionCosts.basic }}</span>
            </button>
            <button
              class="btn-action"
              :disabled="!!busyKey || batchFeeding || awarding || s.points < pointsStore.actionCosts.nice"
              @click="handleAction(s, activePet(s)!, 'nice')"
              :title="`营养粮 -${pointsStore.actionCosts.nice}`"
            >
              <span class="action-icon">🍗</span>
              <span class="cost">-{{ pointsStore.actionCosts.nice }}</span>
            </button>
            <button
              class="btn-action"
              :disabled="!!busyKey || batchFeeding || awarding || s.points < pointsStore.actionCosts.luxury"
              @click="handleAction(s, activePet(s)!, 'luxury')"
              :title="`豪华粮 -${pointsStore.actionCosts.luxury}`"
            >
              <span class="action-icon">🥩</span>
              <span class="cost">-{{ pointsStore.actionCosts.luxury }}</span>
            </button>
          </div>

          <!-- 页码指示点 -->
          <div v-if="s.pets.length > 1" class="pet-dots">
            <span
              v-for="(p, idx) in s.pets"
              :key="p.id"
              class="dot"
              :class="{ active: idx === getIdx(s) }"
              @click="petIdx[s.id] = idx"
            />
          </div>

          <!-- 所有宠物已满级：可领养新宠物 -->
          <button
            v-if="canAdoptFor(s)"
            class="adopt-mini-btn"
            @click="openAdoptDialog(s)"
          >➕ 领养新宠物</button>
        </template>

        <!-- 无宠物 -->
        <template v-else>
          <span class="pet-name-top empty-status">待领养</span>
          <span class="level-badge empty-level">未开启</span>
          <div class="pet-stage empty-pet-stage" aria-hidden="true">
            <div class="egg-halo">
              <span class="empty-egg">🥚</span>
            </div>
          </div>
          <h2 class="pet-name">{{ s.username }}</h2>
          <div class="pet-sub">
            <span class="pet-sub-muted">还没有专属宠物</span>
          </div>
          <button class="adopt-btn" @click="openAdoptDialog(s)"><span>＋</span> 选择宠物</button>
        </template>
      </div>
    </div>

    </div>

    <!-- 批量投喂弹窗 -->
    <div v-if="showBatchFeedDialog" class="dialog-overlay" @click.self="closeBatchFeedDialog">
      <div class="dialog batch-feed-dialog card">
        <div class="batch-dialog-title">
          <div><h3>批量投喂</h3><p>选择要投喂的宠物</p></div>
          <span class="selection-pill">已选 {{ selectedPetIds.length }} 只</span>
        </div>
        <label class="dialog-select-all">
          <input type="checkbox" :checked="allVisibleSelected" :indeterminate="someVisibleSelected" @change="toggleSelectAll" />
          <span>全选</span>
        </label>
        <div class="batch-pet-list">
          <label v-for="option in batchPetOptions" :key="option.pet.id" class="batch-pet-option" :class="{ selected: selectedPetIds.includes(option.pet.id) }">
            <input type="checkbox" :checked="selectedPetIds.includes(option.pet.id)" @change="togglePet(option.pet.id)" />
            <PetAvatar :species="option.pet.species" :level="option.pet.level" :size="46" />
            <span class="batch-pet-copy"><strong>{{ option.pet.name }}</strong><small>{{ option.student.username }} · 饱食度 {{ option.pet.hunger || 0 }}</small></span>
            <span class="option-check">✓</span>
          </label>
        </div>
        <p class="food-section-label">选择食物</p>
        <div class="batch-food-grid">
          <button v-for="food in batchFoods" :key="food.action" type="button" class="batch-food-choice" :class="{ selected: selectedBatchAction === food.action }" :disabled="batchFeeding" @click="selectedBatchAction = food.action">
            <span>{{ food.icon }}</span><strong>{{ food.label }}</strong><small>+{{ food.gain }} · -{{ pointsStore.actionCosts[food.action] }}分/只</small>
          </button>
        </div>
        <div class="dialog-actions batch-dialog-actions">
          <button class="btn-cancel" :disabled="batchFeeding" @click="closeBatchFeedDialog">取消</button>
          <button class="btn btn-primary" :disabled="selectedPetIds.length === 0 || batchFeeding" @click="handleBatchFeed(selectedBatchAction)">{{ batchFeeding ? '投喂中...' : `确认投喂 ${selectedPetIds.length} 只` }}</button>
        </div>
      </div>
    </div>

    <!-- 修改宠物名字弹窗 -->
    <div v-if="showRenameDialog" class="dialog-overlay" @click.self="closeRenameDialog">
      <div class="dialog card">
        <h3>修改宠物名字</h3>
        <p class="rename-hint">{{ renameTargetStudent?.username }} 的宠物</p>
        <div class="rename-field">
          <label for="rename-pet-input">新名字</label>
          <input
            id="rename-pet-input"
            ref="renameInput"
            v-model="renameName"
            class="form-input"
            type="text"
            maxlength="10"
            placeholder="输入宠物的新名字"
            @keyup.enter="handleRename"
          />
          <span class="name-count">{{ renameName.trim().length }}/10</span>
        </div>
        <p v-if="renameError" class="form-error">{{ renameError }}</p>
        <div class="dialog-actions">
          <button class="btn-cancel" :disabled="renaming" @click="closeRenameDialog">取消</button>
          <button class="btn btn-primary" :disabled="!renameName.trim() || renaming" @click="handleRename">
            {{ renaming ? '保存中...' : '保存名字' }}
          </button>
        </div>
      </div>
    </div>

    <!-- 领养弹窗 -->
    <div v-if="showAdoptDialog" class="dialog-overlay" @click.self="closeAdoptDialog">
      <div class="dialog card">
        <h3>为 {{ adoptTarget?.username }} 领养宠物</h3>

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

    <Teleport to="body">
      <Transition name="upgrade-showcase">
        <div v-if="levelUpShowcasePet" class="upgrade-overlay" aria-live="polite">
          <div class="upgrade-center">
            <div class="level-up-fx" aria-hidden="true">
              <i class="fx-rays"></i><i class="fx-ring ring-one"></i><i class="fx-ring ring-two"></i>
              <b v-for="n in 16" :key="n" class="fx-particle" :style="{ '--i': n }">✦</b>
            </div>
            <PetAvatar :species="levelUpShowcasePet.species" :level="levelUpShowcasePet.level" :size="210" show-stage />
            <span v-if="classroomMode" class="upgrade-student-name">{{ levelUpShowcasePet.studentName }} · {{ levelUpShowcasePet.name }}</span>
            <strong>升级成功 · Lv.{{ levelUpShowcasePet.level }}</strong>
          </div>
        </div>
      </Transition>
    </Teleport>

    <div v-if="toast" class="toast">{{ toast }}</div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, nextTick, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'
import { useTasksStore } from '../../stores/tasks'
import { useTeacherStore, type StudentWithPet, type TeacherPet } from '../../stores/teacher'
import { usePointsStore } from '../../stores/points'
import { PET_COLORS, MAX_LEVEL, LEVEL_THRESHOLDS, getFeedingReply } from '../../lib/constants'
import { getPetThemeStyle } from '../../lib/petTheme'
import PetAvatar from '../../components/pet/PetAvatar.vue'
import PetAdoptionFields from '../../components/pet/PetAdoptionFields.vue'

const teacherStore = useTeacherStore()
const pointsStore = usePointsStore()
const initialLoading = ref(true)
const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const tasksStore = useTasksStore()
const classroomMode = computed(() => route.query.classroom === '1')
const classroomDensity = ref(230)
const fullscreen = ref(false)
const awardStudentIds = ref<string[]>([])
const awardTaskId = ref('')
const awarding = ref(false)
const classroomNotice = ref('')
const awardFailures = ref<{ studentId: string; message: string }[]>([])
const awardBubbles = ref<Record<string, string>>({})
const awardTimers = new Map<string, ReturnType<typeof setTimeout>>()
const allAwardSelected = computed(() => sortedStudents.value.length > 0 && sortedStudents.value.every(s => awardStudentIds.value.includes(s.id)))

async function enterClassroom() {
  await router.replace({ query: { ...route.query, classroom: '1' } })
  await tasksStore.fetchTasks()
}
async function exitClassroom() {
  if (document.fullscreenElement) await document.exitFullscreen().catch(() => {})
  const query = { ...route.query }
  delete query.classroom
  await router.replace({ query })
}
async function toggleFullscreen() {
  try {
    if (document.fullscreenElement) await document.exitFullscreen()
    else await document.documentElement.requestFullscreen()
  } catch {
    classroomNotice.value = '当前浏览器未允许全屏，仍可使用课堂大屏。'
  }
}
function syncFullscreen() { fullscreen.value = !!document.fullscreenElement }
function toggleAwardStudent(id: string) {
  if (awarding.value) return
  awardStudentIds.value = awardStudentIds.value.includes(id) ? awardStudentIds.value.filter(x => x !== id) : [...awardStudentIds.value, id]
}
function toggleAwardAll() {
  if (awarding.value) return
  awardStudentIds.value = allAwardSelected.value ? [] : sortedStudents.value.map(s => s.id)
}
async function awardSelected() {
  if (awarding.value || !awardStudentIds.value.length || !awardTaskId.value) return
  awarding.value = true
  awardFailures.value = []
  const taskName = tasksStore.tasks.find(t => t.id === awardTaskId.value)?.name || '课堂奖励'
  try {
    const result = await tasksStore.awardPointsToStudents([...awardStudentIds.value], awardTaskId.value)
    for (const id of result.awardedStudentIds) {
      const student = teacherStore.studentsWithPets.find(s => s.id === id)
      if (student) student.points = result.balances[id] ?? student.points
      awardBubbles.value[id] = `${taskName} +${result.points}`
      clearTimeout(awardTimers.get(id))
      awardTimers.set(id, setTimeout(() => { delete awardBubbles.value[id]; awardTimers.delete(id) }, 3800))
    }
    awardFailures.value = result.failures
    awardStudentIds.value = awardStudentIds.value.filter(id => !result.awardedStudentIds.includes(id))
    classroomNotice.value = result.error
      ? `已奖励 ${result.awardedCount} 人，${awardStudentIds.value.length} 人未完成：${result.error.message}。请先确认结果再重试。`
      : `已为 ${result.awardedCount} 位同学发放「${taskName}」奖励！`
  } finally { awarding.value = false }
}


const searchQuery = ref('')
type PetSort = 'default' | 'name-asc' | 'name-desc' | 'level-asc' | 'level-desc' | 'hunger-asc' | 'hunger-desc'
const sortBy = ref<PetSort>('default')
const nameCollator = new Intl.Collator('zh-CN', { numeric: true, sensitivity: 'base' })
const busyKey = ref<string | null>(null)
const toast = ref('')
const petReplies = ref<Record<string, string>>({})
const hoverPetId = ref<string | null>(null)
const hoverPetReply = ref('')
const levelUpShowcasePet = ref<(TeacherPet & { studentName: string }) | null>(null)
const selectedPetIds = ref<string[]>([])
const showBatchFeedDialog = ref(false)
const batchFeeding = ref(false)
const selectedBatchAction = ref<'basic' | 'nice' | 'luxury'>('basic')
const batchFoods = [
  { action: 'basic' as const, label: '普通粮', icon: '🍖', gain: 20 },
  { action: 'nice' as const, label: '营养粮', icon: '🍗', gain: 50 },
  { action: 'luxury' as const, label: '豪华粮', icon: '🥩', gain: 100 },
]

// 每个学生当前展示的宠物索引（student.id -> pet index）
const petIdx = ref<Record<string, number>>({})

const sortedStudents = computed(() => {
  const students = teacherStore.studentsWithPets.filter(s => s.username.toLocaleLowerCase().includes(searchQuery.value.trim().toLocaleLowerCase()))
  const sort = sortBy.value
  if (sort === 'default') return students
  const direction = sort.endsWith('asc') ? 1 : -1
  return students.sort((a, b) => {
    const nameOrder = nameCollator.compare(a.username, b.username)
    if (sort.startsWith('name')) return direction * nameOrder
    const petA = activePet(a)
    const petB = activePet(b)
    if (!petA || !petB) {
      if (!petA && !petB) return nameOrder
      return petA ? -1 : 1
    }
    const valueOrder = sort.startsWith('level')
      ? petA.level - petB.level
      : (petA.hunger ?? 0) - (petB.hunger ?? 0)
    return direction * valueOrder || nameOrder
  })
})

// 领养弹窗
const showAdoptDialog = ref(false)
const adoptTarget = ref<StudentWithPet | null>(null)
const adoptSpecies = ref('')
const adoptColor = ref(PET_COLORS[0])
const adoptName = ref('')
const adoptError = ref('')
const adopting = ref(false)

// 修改宠物名字弹窗
const showRenameDialog = ref(false)
const renameTargetStudent = ref<StudentWithPet | null>(null)
const renameTargetPet = ref<TeacherPet | null>(null)
const renameName = ref('')
const renameError = ref('')
const renaming = ref(false)
const renameInput = ref<HTMLInputElement | null>(null)
const replyTimers = new Map<string, ReturnType<typeof setTimeout>>()
const HOVER_REPLIES = [
  '你好呀，陪我玩一会儿吧！',
  '今天也要一起加油哦！',
  '见到你真开心！',
  '摸摸我，我会乖乖的～',
  '我正在努力长大！',
  '要不要和我打个招呼？',
] as const
const levelUpQueue: (TeacherPet & { studentName: string })[] = []
let levelUpTimer: ReturnType<typeof setTimeout> | undefined

const batchPetOptions = computed(() => teacherStore.studentsWithPets.flatMap(student => student.pets.map(pet => ({ student, pet }))))
const allVisibleSelected = computed(() => batchPetOptions.value.length > 0 && batchPetOptions.value.every(({ pet }) => selectedPetIds.value.includes(pet.id)))
const someVisibleSelected = computed(() => !allVisibleSelected.value && batchPetOptions.value.some(({ pet }) => selectedPetIds.value.includes(pet.id)))

function canAdoptFor(s: StudentWithPet) {
  return s.pets.length === 0 || s.pets.every(p => (p.level || 1) >= MAX_LEVEL)
}

function xpProgress(pet: TeacherPet): number {
  if (pet.level >= MAX_LEVEL) return 100
  const xp = pet.xp || 0
  const previous = pet.level > 1 ? LEVEL_THRESHOLDS[pet.level - 1] : 0
  const next = LEVEL_THRESHOLDS[pet.level] || previous
  if (next <= previous) return 100
  return Math.max(0, Math.min(100, ((xp - previous) / (next - previous)) * 100))
}

function xpLabel(pet: TeacherPet): string {
  if (pet.level >= MAX_LEVEL) return '已满级'
  return `${pet.xp || 0}/${LEVEL_THRESHOLDS[pet.level]} XP`
}

function getIdx(s: StudentWithPet): number {
  const i = petIdx.value[s.id] || 0
  if (s.pets.length === 0) return 0
  return Math.min(i, s.pets.length - 1)
}

function activePet(s: StudentWithPet): TeacherPet | null {
  if (!s.pets || s.pets.length === 0) return null
  return s.pets[getIdx(s)] || null
}

function prev(s: StudentWithPet) {
  const n = s.pets.length
  if (n <= 1) return
  petIdx.value[s.id] = (getIdx(s) - 1 + n) % n
}

function next(s: StudentWithPet) {
  const n = s.pets.length
  if (n <= 1) return
  petIdx.value[s.id] = (getIdx(s) + 1) % n
}

function togglePet(petId: string) {
  selectedPetIds.value = selectedPetIds.value.includes(petId)
    ? selectedPetIds.value.filter(id => id !== petId)
    : [...selectedPetIds.value, petId]
}

function toggleSelectAll() {
  const visibleIds = batchPetOptions.value.map(({ pet }) => pet.id)
  if (allVisibleSelected.value) {
    const visibleIdSet = new Set(visibleIds)
    selectedPetIds.value = selectedPetIds.value.filter(id => !visibleIdSet.has(id))
  } else {
    selectedPetIds.value = [...new Set([...selectedPetIds.value, ...visibleIds])]
  }
}

function openBatchFeedDialog() {
  selectedPetIds.value = []
  selectedBatchAction.value = 'basic'
  showBatchFeedDialog.value = true
}

function closeBatchFeedDialog() {
  if (!batchFeeding.value) showBatchFeedDialog.value = false
}

async function handleBatchFeed(action: 'basic' | 'nice' | 'luxury') {
  if (batchFeeding.value || awarding.value || busyKey.value || selectedPetIds.value.length === 0) return
  const selectedIds = new Set(selectedPetIds.value)
  const targets = teacherStore.studentsWithPets.flatMap(student => student.pets
    .filter(pet => selectedIds.has(pet.id))
    .map(pet => ({ student, pet })))
  if (targets.length === 0) return

  batchFeeding.value = true
  const failedIds: string[] = []
  let successCount = 0
  for (const { student, pet } of targets) {
    const result = await teacherStore.performActionForStudent(student.id, pet.id, action)
    if (result.error) failedIds.push(pet.id)
    else {
      successCount += 1
      showPetReply(pet.id, getFeedingReply(action))
      if (result.leveledUp) showLevelUpEffect(pet.id)
    }
  }
  batchFeeding.value = false
  showBatchFeedDialog.value = false
  selectedPetIds.value = failedIds
  const food = batchFoods.find(item => item.action === action)!
  showToast(failedIds.length > 0
    ? `${food.label}投喂完成：成功 ${successCount} 只，失败 ${failedIds.length} 只`
    : `已用${food.label}投喂 ${successCount} 只宠物`)
}

function cardStyle(s: StudentWithPet) {
  const p = activePet(s)
  return getPetThemeStyle(p?.appearance?.color, classroomMode.value && awardStudentIds.value.includes(s.id))
}

onMounted(async () => {
  syncFullscreen()
  document.addEventListener('fullscreenchange', syncFullscreen)
  try {
    await Promise.all([
      teacherStore.fetchStudentsWithPets(undefined, true),
      pointsStore.fetchActionCosts(),
      tasksStore.fetchTasks(),
    ])
  } finally {
    initialLoading.value = false
  }
})

onUnmounted(() => {
  document.removeEventListener('fullscreenchange', syncFullscreen)
  awardTimers.forEach(timer => clearTimeout(timer))
  if (classroomMode.value && document.fullscreenElement) void document.exitFullscreen().catch(() => {})
  replyTimers.forEach(timer => clearTimeout(timer))
  if (levelUpTimer) clearTimeout(levelUpTimer)
})

function handleSearch() {
  if (!awarding.value) awardStudentIds.value = []
}

function showToast(msg: string) {
  toast.value = msg
  setTimeout(() => { toast.value = '' }, 2500)
}

async function handleAction(s: StudentWithPet, p: TeacherPet, action: 'basic' | 'nice' | 'luxury') {
  if (!p.id || busyKey.value || batchFeeding.value || awarding.value) return
  busyKey.value = p.id
  const result = await teacherStore.performActionForStudent(s.id, p.id, action)
  busyKey.value = null
  if (result.error) {
    showToast(result.error.message || '操作失败')
    return
  }
  const actionLabel = action === 'basic' ? '普通粮' : action === 'nice' ? '营养粮' : '豪华粮'
  const levelMsg = result.leveledUp ? `，升到 ${result.newLevel} 级！` : ''
  showPetReply(p.id, getFeedingReply(action))
  if (result.leveledUp) showLevelUpEffect(p.id)
  showToast(`已为 ${s.username} 的 ${p.name} 投喂${actionLabel}（-${result.cost} 积分）${levelMsg}`)
}

function showPetReply(petId: string, reply: string) {
  const previousTimer = replyTimers.get(petId)
  if (previousTimer) clearTimeout(previousTimer)
  petReplies.value = { ...petReplies.value, [petId]: reply }
  replyTimers.set(petId, setTimeout(() => {
    const nextReplies = { ...petReplies.value }
    delete nextReplies[petId]
    petReplies.value = nextReplies
    replyTimers.delete(petId)
  }, 3200))
}

function showHoverReply(pet: TeacherPet) {
  if (!pet.id) return
  hoverPetId.value = pet.id
  hoverPetReply.value = HOVER_REPLIES[Math.floor(Math.random() * HOVER_REPLIES.length)]
}

function hideHoverReply() {
  hoverPetId.value = null
  hoverPetReply.value = ''
}

function showLevelUpEffect(petId: string) {
  const pet = teacherStore.studentsWithPets.flatMap(student => student.pets).find(item => item.id === petId)
  if (!pet) return
  const studentName = teacherStore.studentsWithPets.find(student => student.pets.some(p => p.id === petId))?.username || ''
  levelUpQueue.push({ ...pet, studentName })
  if (levelUpShowcasePet.value) return
  const showNext = () => {
    levelUpShowcasePet.value = levelUpQueue.shift() || null
    if (!levelUpShowcasePet.value) return
    levelUpTimer = setTimeout(() => {
      levelUpShowcasePet.value = null
      levelUpTimer = setTimeout(showNext, 180)
    }, 2100)
  }
  showNext()
}

function openRenameDialog(student: StudentWithPet, pet: TeacherPet) {
  renameTargetStudent.value = student
  renameTargetPet.value = pet
  renameName.value = pet.name
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
  renameTargetStudent.value = null
  renameTargetPet.value = null
  renameName.value = ''
  renameError.value = ''
}

async function handleRename() {
  if (!renameTargetStudent.value || !renameTargetPet.value || renaming.value) return
  const newName = renameName.value.trim()
  if (!newName || newName.length > 10) {
    renameError.value = '宠物名字需要 1-10 个字符'
    return
  }
  if (newName === renameTargetPet.value.name) {
    closeRenameDialog()
    return
  }

  renaming.value = true
  renameError.value = ''
  const { error, name } = await teacherStore.renamePetForStudent(
    renameTargetStudent.value.id,
    renameTargetPet.value.id,
    newName,
  )
  renaming.value = false
  if (error) {
    renameError.value = error.message || '修改失败，请重试'
    return
  }
  showToast(`宠物名字已修改为「${name}」`)
  closeRenameDialog()
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
    target.pets = [...(target.pets || []), data]
    // 自动跳转到新领养的宠物
    petIdx.value[target.id] = target.pets.length - 1
  }
  showToast(`已为 ${adoptTarget.value.username} 领养宠物`)
  closeAdoptDialog()
}
</script>

<style scoped>
.pets-toolbar, .pets-content { display: contents; }
.classroom-mode .pets-toolbar { flex: 0 0 auto; display: grid; grid-template-columns: minmax(380px, .9fr) minmax(0, 1.4fr); align-items: center; gap: 12px 24px; padding: 18px 24px; background: #f8fcf8; border-bottom: 1px solid #d4e4d9; box-shadow: 0 3px 12px #24473508; }
.classroom-mode .pets-toolbar .page-title-row { grid-column: 1 / -1; margin: 0; }
:global(#app .app-shell .classroom-mode .search-bar) { max-width: none; margin: 0; gap: 10px; }
.classroom-mode .search-bar > .form-input { flex-basis: 140px; }
.classroom-mode .sort-select { min-width: 150px; max-width: 220px; }
.classroom-mode .sort-hint { grid-column: 1 / -1; margin: 0; order: 1; }
.classroom-mode .pets-content { display: block; flex: 1 1 0; min-height: 0; overflow-y: auto; overscroll-behavior: contain; scrollbar-gutter: stable; padding: 20px 24px 32px; }
.page-actions { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
:global(#app .app-shell .page.classroom-mode) { position: fixed; inset: 0; z-index: 100; width: 100%; max-width: none; height: 100dvh; min-height: 0; display: flex; flex-direction: column; overflow: hidden; padding: 0; background: radial-gradient(ellipse at 10% 0%, #e0f4e9, transparent 55%), #f5f7ef; }
.classroom-mode .page-title { font-size: clamp(24px, 2.4vw, 38px); color: #254d42; }
.classroom-eyebrow { color: #53736a; margin: 0 0 8px; font-size: 16px; }
.density-select { width: auto; }
.classroom-award-bar { padding: 8px 10px; border-radius: 12px; background: #eef3ef; border: 1px solid transparent; transition: background .2s, border-color .2s; font-size: 13px; display: flex; align-items: center; flex-wrap: wrap; gap: 10px; margin: 0; min-width: 0; }
.classroom-select-all { white-space: nowrap; display: flex; align-items: center; gap: 8px; }
.classroom-task { flex: 1 1 150px; width: auto; max-width: 320px; }
.classroom-task-hint { width: 100%; color: #6c766a; }
.classroom-notice { padding: 12px 18px; color: #285b43; background: #e3f3e7; border-radius: 12px; margin-bottom: 18px; }
.classroom-failures { padding: 14px 34px; color: #a33441; background: #fff0ef; border-radius: 12px; }
:global(#app .app-shell .classroom-mode .pet-list) { grid-template-columns: repeat(auto-fill, minmax(min(100%, var(--classroom-card-width)), 1fr)); gap: 20px; }
.pets-page .pet-card { border: 2px solid #ffffff; border-radius: 22px; box-shadow: 0 4px 18px #233d3210; }
.classroom-mode .pet-card { padding-top: 48px; }
.pets-page .pet-card.empty-adopt-card::before { display: none; }
.classroom-mode .pet-card:hover { box-shadow: 0 8px 24px #233d321c; }
.classroom-mode .pet-card:has(.classroom-student-select input:focus-visible) { outline: 3px solid #297d60; outline-offset: 3px; }
.classroom-mode .pet-card.award-selected { background: linear-gradient(160deg, color-mix(in srgb, var(--pet-tone) 30%, white), #f8fcf9 78%); }
.pets-page .pet-card .points-badge { background: #fff; color: #436655; box-shadow: none; font-size: 12px; }
.pets-page .pet-card .level-badge { background: #fff; color: #807044; box-shadow: none; }
.classroom-mode .pet-card .level-badge { right: 46px; }
.pets-page .pet-card .pet-stats { background: #f1f5f2; opacity: .85; }
.pets-page .pet-card .stat-fill { background: #9abaad; }
.pets-page .pet-card .xp-fill { background: #b6abd0; }
.classroom-mode .pet-card .action-row { gap: 6px; }
.pets-page .pet-card .btn-action { background: #ffffffb3; border: 1px solid #e6ece7; border-radius: 12px; }
.pets-page .pet-card .cost { color: #668070; }
.classroom-mode .pet-card .action-row, .classroom-mode .pet-card .pet-dots, .classroom-mode .pet-card .adopt-btn { position: relative; z-index: 3; }
.classroom-mode .pet-card .nav-arrow { z-index: 3; }
.classroom-award-bar.has-selection { background: #e7f2eb; border-color: #bfd8c8; }
.award-count { white-space: nowrap; color: #698075; }
.award-count strong { color: #28684c; }
.clear-selection { border: 0; padding: 7px 3px; color: #61776b; background: none; cursor: pointer; white-space: nowrap; }
:global(#app .app-shell .classroom-mode .btn-primary) { background: #36795c; box-shadow: none; color: white; }
:global(#app .app-shell .classroom-mode .btn-secondary) { border: 1px solid #d7e2da; color: #536c5e; background: #fff; box-shadow: none; }
:global(#app .app-shell .classroom-mode .form-input) { border: 1px solid #dce6df; border-radius: 10px; background: #fff; font-size: 13px; }
.classroom-award-bar .btn { padding: 10px 16px; font-size: 13px; border-radius: 10px; white-space: nowrap; }

.classroom-mode .pet-card.award-selected { border-color: #297d60; box-shadow: 0 0 0 3px #297d6022; }
.classroom-mode .pet-stage {
  height: 150px;
  z-index: 3;
}
.classroom-compact .pet-stage { height: 120px; }
.classroom-compact .pet-card { gap: 5px; }
.classroom-mode .pet-name { font-size: 25px; overflow-wrap: anywhere; }
.classroom-mode .pet-name-top { top: 39px; color: #7d8d83; font-weight: 400; }
.classroom-mode .rename-pet-btn, .classroom-mode .adopt-mini-btn { display: none; }
.classroom-student-select { position: absolute; inset: 0; z-index: 2; border-radius: inherit; cursor: pointer; }
.classroom-student-select input { position: absolute; inset: 0; width: 100%; height: 100%; margin: 0; opacity: 0; cursor: pointer; }
.classroom-student-select input:disabled { cursor: wait; }
.card-selection-mark { position: absolute; right: 12px; top: 12px; display: grid; place-items: center; width: 22px; height: 22px; border: 1.5px solid #c5d4c9; border-radius: 50%; background: #ffffffb3; color: transparent; font-size: 14px; pointer-events: none; }
.award-selected .card-selection-mark { background: #36795c; border-color: #36795c; color: #fff; }
.classroom-select-all input { accent-color: #36795c; width: 16px; height: 16px; }
.award-bubble { position: absolute; z-index: 35; top: 80px; left: 8px; right: 8px; background: #fff9d9; color: #77510a; padding: 12px; border-radius: 15px; font-weight: 800; text-align: center; box-shadow: 0 6px 18px #55400025; overflow-wrap: anywhere; }
.award-bounce .pet-stage { animation: reward-hop .7s ease 2; }
.upgrade-student-name { font-size: 30px; font-weight: 800; color: #fff; text-shadow: 0 2px 10px #444; }
@keyframes reward-hop { 0%,100% { transform: translateY(0); } 45% { transform: translateY(-18px) rotate(-4deg); } 70% { transform: translateY(-5px) rotate(3deg); } }
@media (max-width: 1100px) {
  .classroom-mode .pets-toolbar { grid-template-columns: minmax(0, 1fr); }
}
@media (max-width: 700px) {
  .classroom-mode .pets-toolbar { padding: 12px; gap: 10px; max-height: 50dvh; overflow-y: auto; }
  .classroom-mode .pets-content { padding: 14px 12px 28px; }
  .classroom-mode .page-title-row { align-items: flex-start; flex-direction: column; }
  .classroom-mode .classroom-eyebrow { margin-bottom: 4px; font-size: 13px; }
  .classroom-mode .page-title { font-size: 22px; }
}
@media (prefers-reduced-motion: reduce) { .award-bounce .pet-stage { animation: none; } }

.teacher-page {
  padding-bottom: 80px;
}

.search-bar {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;
  margin-bottom: 16px;
}

.search-bar > .form-input {
  flex: 1 1 240px;
  min-width: 0;
}

.sort-control {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--color-text-muted);
  font-size: .85rem;
}

.sort-select {
  width: auto;
  min-width: 190px;
  cursor: pointer;
}

.sort-hint {
  margin: -6px 0 14px;
  color: var(--color-text-muted);
  font-size: .78rem;
}

.page-title-row { display: flex; align-items: center; justify-content: space-between; gap: 16px; margin-bottom: 16px; }
.page-title-row .page-title { margin: 0; }
.batch-entry-btn { padding: 8px 16px; font-size: .84rem; }
.batch-entry-btn:disabled { opacity: .45; cursor: not-allowed; }

.loading-state, .empty-state {
  text-align: center;
  color: #999;
  padding: 32px;
}

.pet-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 14px;
}

.pet-card {
  position: relative;
  padding: 30px 10px 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.08);
  transition: transform 0.2s, box-shadow 0.2s;
}

.pet-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 22px rgba(0, 0, 0, 0.14);
}

.pet-card.level-up-card {
  z-index: 30;
  transform: none;
  box-shadow: 0 12px 34px rgba(116, 68, 91, .18);
}

.empty-adopt-card {
  min-height: 432px;
  gap: 8px;
  overflow: hidden;
  border: 1px solid rgba(237, 164, 190, 0.38);
  box-shadow: 0 4px 14px rgba(111, 65, 82, 0.07);
}

.empty-adopt-card::before {
  content: '';
  position: absolute;
  width: 210px;
  height: 210px;
  top: 62px;
  left: 50%;
  transform: translateX(-50%);
  border-radius: 50%;
  background: radial-gradient(circle, rgba(255, 201, 221, 0.28), rgba(255, 231, 239, 0.08) 56%, transparent 72%);
  pointer-events: none;
}

.empty-status {
  color: #a96d83;
  font-style: normal;
  letter-spacing: 0.04em;
}

.empty-level {
  color: #a96d83;
  background: rgba(255, 255, 255, .75);
  border: 1px solid rgba(214, 133, 163, .25);
  box-shadow: none;
}

.empty-pet-stage {
  z-index: 1;
}

.egg-halo {
  position: relative;
  display: grid;
  place-items: center;
  width: 132px;
  height: 132px;
  border-radius: 50%;
  background: rgba(255, 255, 255, .7);
  border: 1px solid rgba(228, 150, 178, .28);
  box-shadow: inset 0 0 0 9px rgba(255, 238, 244, .62), 0 12px 28px rgba(129, 75, 95, .1);
}

.egg-halo::after {
  content: '';
  position: absolute;
  left: 31px;
  right: 31px;
  bottom: 23px;
  height: 11px;
  border-radius: 50%;
  background: rgba(91, 51, 66, .13);
  filter: blur(5px);
  animation: egg-shadow 2.6s ease-in-out infinite;
}

.empty-egg {
  position: relative;
  z-index: 1;
  font-size: 4.3rem;
  line-height: 1;
  filter: drop-shadow(0 8px 7px rgba(104, 57, 74, .18));
  animation: empty-egg-float 2.6s ease-in-out infinite;
}

@keyframes empty-egg-float {
  0%, 100% { transform: translateY(0) rotate(-1deg); }
  50% { transform: translateY(-5px) rotate(1deg); }
}

@keyframes egg-shadow {
  0%, 100% { transform: scaleX(1); opacity: .68; }
  50% { transform: scaleX(.82); opacity: .42; }
}

.pet-stage {
  position: relative;
  display: grid;
  place-items: center;
  width: 100%;
  height: 170px;
  margin: -2px 0 0;
}

.pet-speech {
  position: absolute;
  top: 4px;
  right: 4px;
  z-index: 4;
  max-width: 118px;
  padding: 7px 9px;
  border: 1px solid rgba(255, 105, 155, .2);
  border-radius: 12px 12px 12px 4px;
  background: rgba(255, 255, 255, .94);
  color: #6b3b4d;
  font-size: .68rem;
  line-height: 1.35;
  box-shadow: 0 5px 14px rgba(94, 50, 67, .14);
}

.pet-speech::after {
  content: '';
  position: absolute;
  left: 9px;
  bottom: -6px;
  border-width: 6px 6px 0 0;
  border-style: solid;
  border-color: rgba(255, 255, 255, .94) transparent transparent transparent;
}

.pet-stage.level-up-active::before,
.pet-stage.level-up-active::after {
  content: '';
  position: absolute;
  left: 50%;
  top: 50%;
  z-index: 0;
  width: 118px;
  height: 118px;
  border-radius: 50%;
  pointer-events: none;
  transform: translate(-50%, -50%);
}

.pet-stage.level-up-active::before {
  background: radial-gradient(circle, rgba(255,255,255,.98) 0%, rgba(255,230,120,.72) 35%, rgba(255,149,213,.22) 62%, transparent 72%);
  animation: level-glow 1.6s ease-out;
}

.pet-stage.level-up-active::after {
  border: 3px solid rgba(255, 238, 128, .9);
  box-shadow: 0 0 18px #fff3a3, inset 0 0 16px rgba(255,255,255,.9);
  animation: level-ring 1.6s ease-out;
}

.pet-stage.level-up-active :deep(.pet-avatar-wrap) { position: relative; animation: level-pet-pop 2s cubic-bezier(.2,.72,.25,1); z-index: 8; }

.level-up-fx { position: absolute; inset: 0; z-index: 3; overflow: visible; pointer-events: none; animation: fx-follow-pet 2s cubic-bezier(.2,.72,.25,1); }
.fx-rays { position: absolute; left: 50%; top: 50%; width: 145px; height: 145px; border-radius: 50%; background: repeating-conic-gradient(from 0deg, rgba(255,255,255,.95) 0 4deg, transparent 4deg 18deg), conic-gradient(#ff4fa3, #ffe95b, #70fff2, #8c6cff, #ff4fa3); opacity: 0; mix-blend-mode: screen; transform: translate(-50%,-50%); animation: fx-rays-spin 1.65s ease-out; mask: radial-gradient(circle, transparent 0 28%, #000 31% 62%, transparent 72%); }
.fx-ring { position: absolute; left: 50%; top: 50%; width: 92px; height: 92px; border: 4px solid #fff; border-radius: 50%; box-shadow: 0 0 10px #fff, 0 0 24px #ffe76c, 0 0 38px #ff5fc5; transform: translate(-50%,-50%); }
.ring-one { animation: fx-ring-burst 1.5s ease-out forwards; }
.ring-two { border-color: #7dfff2; animation: fx-ring-burst 1.5s .16s ease-out forwards; }
.fx-particle { --angle: calc(var(--i) * 30deg); position: absolute; left: 50%; top: 50%; color: #fff8a8; font-size: 18px; text-shadow: 0 0 5px white, 0 0 10px #ff4fb7; opacity: 0; animation: fx-particle-fly 1.45s calc(var(--i) * 22ms) cubic-bezier(.12,.7,.2,1) forwards; }

@keyframes level-glow { 0% { opacity: 0; transform: translate(-50%, -50%) scale(.35); } 28% { opacity: 1; } 100% { opacity: 0; transform: translate(-50%, -50%) scale(1.65); } }
@keyframes level-ring { 0% { opacity: 0; transform: translate(-50%, -50%) scale(.55); } 22% { opacity: 1; } 100% { opacity: 0; transform: translate(-50%, -50%) scale(1.5); } }
@keyframes level-pet-pop {
  0% { transform: translateY(0) scale(1); filter: brightness(1); }
  12% { transform: translateY(8px) scale(.94); }
  28% { transform: translateY(-78px) scale(1.62); filter: brightness(1.65) saturate(1.5) drop-shadow(0 0 24px #fff5a6); }
  58% { transform: translateY(-88px) scale(1.7) rotate(-2deg); filter: brightness(1.42) saturate(1.65) drop-shadow(0 0 30px #ff71ca); }
  72% { transform: translateY(-78px) scale(1.62) rotate(2deg); }
  90% { transform: translateY(5px) scale(.98); filter: brightness(1.08); }
  100% { transform: translateY(0) scale(1); filter: brightness(1); }
}
@keyframes fx-rays-spin { 0% { opacity: 0; transform: translate(-50%,-50%) scale(.2) rotate(0); } 24% { opacity: .9; } 100% { opacity: 0; transform: translate(-50%,-50%) scale(1.65) rotate(150deg); } }
@keyframes fx-ring-burst { 0% { opacity: 0; transform: translate(-50%,-50%) scale(.25); } 25% { opacity: 1; } 100% { opacity: 0; transform: translate(-50%,-50%) scale(1.85); } }
@keyframes fx-particle-fly { 0% { opacity: 0; transform: translate(-50%,-50%) rotate(var(--angle)) translateY(0) scale(.35); } 20% { opacity: 1; } 75% { opacity: 1; } 100% { opacity: 0; transform: translate(-50%,-50%) rotate(var(--angle)) translateY(-84px) scale(1.25); } }
@keyframes fx-follow-pet { 0%, 12%, 100% { transform: translateY(0); } 28%, 72% { transform: translateY(-78px); } 58% { transform: translateY(-88px); } 90% { transform: translateY(5px); } }

.speech-pop-enter-active, .speech-pop-leave-active { transition: opacity .2s ease, transform .2s ease; }
.speech-pop-enter-from, .speech-pop-leave-to { opacity: 0; transform: translateY(4px) scale(.94); }

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

.level-badge.max-badge {
  background: linear-gradient(135deg, #A78BFA, #6366F1);
  box-shadow: 0 2px 6px rgba(99, 102, 241, 0.35);
}

.points-badge {
  position: absolute;
  top: 8px;
  left: 8px;
  background: linear-gradient(135deg, #10B981, #059669);
  color: white;
  padding: 2px 8px;
  border-radius: 16px;
  font-size: 0.68rem;
  font-weight: 700;
  box-shadow: 0 2px 6px rgba(16, 185, 129, 0.3);
  z-index: 1;
}

.pet-name-muted {
  color: rgba(0, 0, 0, 0.4);
  font-style: italic;
}

.pet-name-top {
  position: absolute;
  top: 9px;
  left: 50%;
  transform: translateX(-50%);
  max-width: 50%;
  font-size: 0.75rem;
  font-weight: 600;
  color: rgba(0, 0, 0, 0.75);
  display: flex;
  align-items: center;
  gap: 3px;
  z-index: 1;
}

.pet-name-top > span {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rename-pet-btn {
  flex: 0 0 auto;
  width: 20px;
  height: 20px;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.72);
  color: var(--color-primary);
  font-size: 0.72rem;
  line-height: 20px;
  cursor: pointer;
  opacity: 0.75;
  transition: opacity 0.2s, background 0.2s;
}

.rename-pet-btn:hover,
.rename-pet-btn:focus-visible {
  opacity: 1;
  background: white;
}

.pet-name-top-muted {
  color: rgba(0, 0, 0, 0.4);
  font-style: italic;
}

.adopt-card {
  background: #fafafa !important;
  border: 1.5px dashed #e0e0e0;
}

.nav-arrow {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  width: 26px;
  height: 26px;
  padding: 0;
  border-radius: 50%;
  border: 1px solid rgba(255, 255, 255, 0.72);
  background: rgba(255, 255, 255, 0.68);
  color: rgba(45, 36, 41, 0.72);
  cursor: pointer;
  font-family: Arial, sans-serif;
  font-size: 1.05rem;
  line-height: 23px;
  display: grid;
  place-items: center;
  box-shadow: 0 2px 5px rgba(42, 30, 36, 0.12);
  z-index: 2;
  transition: background 0.2s, transform 0.15s;
}

.nav-arrow:hover {
  background: rgba(255, 255, 255, 0.92);
  color: #333;
  transform: translateY(-50%) scale(1.05);
}

.nav-arrow:focus-visible {
  outline: 3px solid rgba(255, 255, 255, 0.65);
  outline-offset: 2px;
}

.nav-arrow.left { left: -2px; }
.nav-arrow.right { right: -2px; }

.pet-dots {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-top: 4px;
}

.pet-dots .dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: rgba(0, 0, 0, 0.25);
  cursor: pointer;
  transition: all 0.2s;
}

.pet-dots .dot.active {
  background: rgba(0, 0, 0, 0.65);
  width: 14px;
  border-radius: 3px;
}

.adopt-mini-btn {
  margin-top: 4px;
  padding: 5px 12px;
  border-radius: 20px;
  border: 1.5px dashed rgba(0, 0, 0, 0.25);
  background: rgba(255, 255, 255, 0.7);
  color: #333;
  font-size: 0.72rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.2s;
}

.adopt-mini-btn:hover {
  background: #fff;
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
  font-family: var(--font-body);
  font-size: 1.125rem;
  font-weight: 600;
  line-height: 1.6;
  letter-spacing: 0.06em;
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
  color: rgba(0, 0, 0, 0.55);
  max-width: 100%;
  overflow: hidden;
  white-space: nowrap;
}

.pet-sub-name {
  color: rgba(0, 0, 0, 0.75);
  font-weight: 600;
  max-width: 70px;
  overflow: hidden;
  text-overflow: ellipsis;
}

.pet-sub-muted {
  color: rgba(0, 0, 0, 0.4);
  font-style: italic;
}

.pet-sub-dot {
  color: rgba(0, 0, 0, 0.3);
}

.pet-sub-points {
  color: #2f855a;
  font-weight: 600;
}

.pet-stats {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 6px 8px;
  background: rgba(255, 255, 255, 0.55);
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
  background: rgba(0, 0, 0, 0.15);
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
  border: 1.5px solid rgba(255, 255, 255, 0.8);
  background: rgba(255, 255, 255, 0.75);
  color: #444;
  cursor: pointer;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1px;
  transition: all 0.2s;
}

.btn-action:hover:not(:disabled) {
  background: #fff;
  border-color: #fff;
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
  margin-top: 10px;
  padding: 8px 17px;
  border: 1px solid rgba(222, 103, 150, .32);
  border-radius: 999px;
  background: rgba(255,255,255,.78);
  color: #d64f84;
  font-size: .78rem;
  font-weight: 700;
  cursor: pointer;
  box-shadow: 0 6px 16px rgba(183, 91, 126, .12);
  transition: transform .2s ease, box-shadow .2s ease, background .2s ease;
}

.xp-fill {
  background: linear-gradient(90deg, #8b5cf6, #ec4899);
}

.xp-stat .stat-bar {
  background: rgba(255, 255, 255, .58);
}

.stat-value {
  width: auto !important;
  min-width: 58px;
  color: rgba(0, 0, 0, .58);
  font-size: .58rem;
  text-align: right !important;
  white-space: nowrap;
}

.adopt-btn:hover {
  transform: translateY(-2px);
  background: #fff;
  box-shadow: 0 9px 20px rgba(183, 91, 126, .2);
}

@media (prefers-reduced-motion: reduce) {
  .empty-egg, .egg-halo::after { animation: none; }
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

.batch-feed-dialog { max-width: 460px; overflow: hidden; }
.batch-dialog-title { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.batch-dialog-title h3 { margin: 0 0 3px; }
.batch-dialog-title p { margin: 0; color: var(--color-text-muted); font-size: .78rem; }
.selection-pill { padding: 4px 10px; border-radius: 999px; background: #fff0f5; color: var(--color-primary); font-size: .75rem; font-weight: 700; }
.dialog-select-all { display: flex; align-items: center; gap: 7px; margin: 16px 0 8px; color: #666; font-size: .8rem; cursor: pointer; }
.dialog-select-all input, .batch-pet-option input { width: 17px; height: 17px; accent-color: var(--color-primary); cursor: pointer; }
.batch-pet-list { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; max-height: 265px; overflow-y: auto; padding: 2px; }
.batch-pet-option { position: relative; display: flex; align-items: center; gap: 8px; min-width: 0; padding: 9px; border: 1.5px solid #eee; border-radius: 12px; background: #fff; cursor: pointer; transition: .18s ease; }
.batch-pet-option:hover { border-color: #ffc0d5; background: #fff9fb; }
.batch-pet-option.selected { border-color: var(--color-primary); background: #fff0f5; box-shadow: 0 4px 12px rgba(255,105,155,.12); }
.batch-pet-option > input { position: absolute; opacity: 0; pointer-events: none; }
.batch-pet-copy { display: flex; flex-direction: column; min-width: 0; gap: 2px; }
.batch-pet-copy strong, .batch-pet-copy small { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.batch-pet-copy strong { font-size: .84rem; }
.batch-pet-copy small { color: var(--color-text-muted); font-size: .7rem; }
.option-check { display: none; margin-left: auto; width: 20px; height: 20px; border-radius: 50%; background: var(--color-primary); color: white; place-items: center; font-size: .68rem; }
.batch-pet-option.selected .option-check { display: grid; }
.food-section-label { margin: 17px 0 8px; color: #666; font-size: .8rem; font-weight: 600; }
.batch-food-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.batch-food-choice { display: flex; flex-direction: column; align-items: center; gap: 3px; padding: 10px 5px; border: 1.5px solid #eee; border-radius: 11px; background: white; color: var(--color-text); cursor: pointer; }
.batch-food-choice > span { font-size: 1.35rem; }
.batch-food-choice strong { font-size: .78rem; }
.batch-food-choice small { color: var(--color-text-muted); font-size: .66rem; }
.batch-food-choice.selected { border-color: var(--color-primary); background: #fff0f5; box-shadow: 0 4px 12px rgba(255,105,155,.12); }
.batch-dialog-actions { margin-top: 18px; }

@media (max-width: 480px) {
  .batch-pet-list { grid-template-columns: 1fr; }
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
  font-size: 0.88rem;
  z-index: 300;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  max-width: 80vw;
  text-align: center;
}

.upgrade-overlay { position: fixed; inset: 0; z-index: 1000; display: grid; place-items: center; overflow: hidden; background: radial-gradient(circle at center, rgba(74,35,91,.2), rgba(24,13,31,.62)); backdrop-filter: blur(3px); pointer-events: none; }
.upgrade-center { position: relative; display: flex; width: 320px; height: 360px; flex-direction: column; align-items: center; justify-content: center; color: white; text-align: center; text-shadow: 0 2px 10px rgba(64,20,72,.55); }
.upgrade-center > :deep(.pet-avatar-wrap) { position: relative; z-index: 8; animation: center-pet-upgrade 2s cubic-bezier(.2,.72,.25,1); }
.upgrade-center > strong { position: relative; z-index: 9; margin-top: 20px; padding: 7px 18px; border: 1px solid rgba(255,255,255,.65); border-radius: 999px; background: rgba(117,56,138,.62); font-size: 1rem; box-shadow: 0 0 24px rgba(255,111,210,.55); animation: upgrade-title-in 2s ease both; }
.upgrade-center .level-up-fx { inset: 0; animation: none; }
.upgrade-center .fx-rays, .upgrade-center .fx-ring, .upgrade-center .fx-particle { top: 47%; }
.upgrade-showcase-enter-active, .upgrade-showcase-leave-active { transition: opacity .2s ease; }
.upgrade-showcase-enter-from, .upgrade-showcase-leave-to { opacity: 0; }
@keyframes center-pet-upgrade { 0% { opacity: 0; transform: translateY(130px) scale(.55); filter: brightness(1); } 24% { opacity: 1; transform: translateY(-24px) scale(1.18); filter: brightness(1.7) saturate(1.5) drop-shadow(0 0 30px #fff3a3); } 55% { transform: translateY(-38px) scale(1.28) rotate(-2deg); filter: brightness(1.45) saturate(1.7) drop-shadow(0 0 42px #ff65c7); } 72% { transform: translateY(-28px) scale(1.2) rotate(2deg); } 100% { opacity: 1; transform: translateY(0) scale(1); filter: brightness(1); } }
@keyframes upgrade-title-in { 0%, 25% { opacity: 0; transform: translateY(14px) scale(.85); } 45%, 88% { opacity: 1; transform: translateY(0) scale(1); } 100% { opacity: 0; } }
</style>
