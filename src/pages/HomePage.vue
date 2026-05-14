<template>
  <div class="page">
    <div v-if="petStore.loading && petStore.pets.length === 0" class="loading">
      <span class="animate-bounce">🐾</span>
      <p>加载中...</p>
    </div>

    <template v-else-if="petStore.currentPet">
      <!-- 积分余额 -->
      <div class="points-banner">
        <span class="points-icon">⭐</span>
        <span class="points-value">{{ authStore.user?.points || 0 }}</span>
        <span class="points-label">积分</span>
      </div>

      <!-- 宠物切换条 -->
      <div v-if="petStore.pets.length > 1 || petStore.canAdoptNew" class="pet-switcher">
        <button
          v-for="p in petStore.pets"
          :key="p.id"
          class="switcher-item"
          :class="{ active: p.id === petStore.currentPet?.id }"
          :title="`${p.name} · Lv.${p.level}`"
          :style="{ background: p.id === petStore.currentPet?.id ? p.appearance?.color : 'white' }"
          @click="petStore.selectPet(p.id)"
        >
          <PetAvatar
            :species="p.species"
            :level="p.level"
            :size="40"
          />
          <span class="switcher-lv">Lv.{{ p.level }}</span>
        </button>
        <button
          v-if="petStore.canAdoptNew"
          class="switcher-item switcher-add"
          title="领养新宠物"
          @click="router.push('/pet/create')"
        >
          <span class="switcher-add-icon">＋</span>
        </button>
      </div>

      <!-- 宠物展示 -->
      <div class="pet-display card" :style="{ background: petStore.currentPet.appearance.color }">
        <PetAvatar
          class="pet-avatar animate-float"
          :species="petStore.currentPet.species"
          :level="petStore.currentPet.level"
          :size="200"
          show-stage
        />
        <h2 class="pet-name">{{ petStore.currentPet.name }}</h2>
        <div class="pet-level">
          <span class="level-badge">Lv.{{ petStore.currentPet.level }}</span>
          <div class="xp-bar">
            <div class="progress-bar">
              <div class="progress-fill" :style="{ width: xpPercent + '%', background: 'linear-gradient(90deg, var(--color-primary), var(--color-secondary))' }"></div>
            </div>
            <span class="xp-text">
              <template v-if="petStore.currentPet.level >= MAX_LEVEL">已进化为完全体</template>
              <template v-else>{{ petStore.currentPet.xp }} / {{ nextLevelXp }} XP</template>
            </span>
          </div>
        </div>
      </div>

      <!-- 状态条 -->
      <div class="stats-grid">
        <div class="stat-item">
          <span class="stat-icon">🍖</span>
          <div class="stat-info">
            <span class="stat-label">饱食</span>
            <div class="progress-bar">
              <div class="progress-fill" :style="{ width: petStore.currentPet.hunger + '%', background: '#4ECDC4' }"></div>
            </div>
          </div>
          <span class="stat-val">{{ petStore.currentPet.hunger }}</span>
        </div>
      </div>

      <!-- 互动按钮 -->
      <div class="actions-grid">
        <button
          class="action-btn"
          :disabled="!canAfford('basic')"
          @click="doAction('basic')"
        >
          <span class="action-icon">🍖</span>
          <span class="action-label">普通粮</span>
          <span class="action-cost">{{ pointsStore.actionCosts.basic }} 积分</span>
        </button>
        <button
          class="action-btn"
          :disabled="!canAfford('nice')"
          @click="doAction('nice')"
        >
          <span class="action-icon">🍗</span>
          <span class="action-label">营养粮</span>
          <span class="action-cost">{{ pointsStore.actionCosts.nice }} 积分</span>
        </button>
        <button
          class="action-btn"
          :disabled="!canAfford('luxury')"
          @click="doAction('luxury')"
        >
          <span class="action-icon">🥩</span>
          <span class="action-label">豪华粮</span>
          <span class="action-cost">{{ pointsStore.actionCosts.luxury }} 积分</span>
        </button>
      </div>

      <!-- 消息提示 -->
      <div v-if="message" class="toast" :class="{ error: isError }">{{ message }}</div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { usePetStore } from '../stores/pet'
import { useAuthStore } from '../stores/auth'
import { usePointsStore } from '../stores/points'
import { LEVEL_THRESHOLDS, MAX_LEVEL } from '../lib/constants'
import PetAvatar from '../components/pet/PetAvatar.vue'

const router = useRouter()
const petStore = usePetStore()
const authStore = useAuthStore()
const pointsStore = usePointsStore()
const message = ref('')
const isError = ref(false)

const nextLevelXp = computed(() => {
  if (!petStore.currentPet) return 50
  const level = petStore.currentPet.level
  if (level >= LEVEL_THRESHOLDS.length) return LEVEL_THRESHOLDS[LEVEL_THRESHOLDS.length - 1]
  return LEVEL_THRESHOLDS[level]
})

const xpPercent = computed(() => {
  if (!petStore.currentPet) return 0
  const current = petStore.currentPet.xp
  const level = petStore.currentPet.level
  if (level >= MAX_LEVEL) return 100
  const prevThreshold = level > 1 ? LEVEL_THRESHOLDS[level - 1] : 0
  const next = nextLevelXp.value
  if (next === prevThreshold) return 100
  return Math.min(100, ((current - prevThreshold) / (next - prevThreshold)) * 100)
})

function canAfford(action: 'basic' | 'nice' | 'luxury') {
  return (authStore.user?.points || 0) >= pointsStore.actionCosts[action]
}

async function doAction(action: 'basic' | 'nice' | 'luxury') {
  const result = await petStore.performAction(action)
  if (result) {
    isError.value = !result.success
    message.value = result.message
    setTimeout(() => { message.value = '' }, 2500)
  }
}

onMounted(async () => {
  await Promise.all([
    petStore.fetchPets(),
    pointsStore.fetchActionCosts(),
  ])
  if (petStore.pets.length === 0) {
    router.push('/pet/create')
  }
})
</script>

<style scoped>
.loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 60vh;
  font-size: 2rem;
}

.loading p {
  font-size: 1rem;
  color: var(--color-text-muted);
  margin-top: 12px;
}

.points-banner {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  background: linear-gradient(135deg, #FFF8E1, #FFECB3);
  border: 1px solid #FFD54F;
  border-radius: var(--radius);
  padding: 12px;
  margin-bottom: 16px;
}

.points-icon {
  font-size: 1.3rem;
}

.points-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: #F57F17;
}

.points-label {
  font-size: 0.85rem;
  color: #F9A825;
}

.pet-switcher {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 4px 2px 12px;
  margin-bottom: 8px;
  scrollbar-width: none;
}

.pet-switcher::-webkit-scrollbar { display: none; }

.switcher-item {
  background: white;
  border: 2px solid transparent;
  border-radius: var(--radius);
  padding: 6px 8px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  cursor: pointer;
  transition: all 0.2s;
  flex-shrink: 0;
}

.switcher-item:hover {
  border-color: var(--color-primary-light, #FFC0CB);
}

.switcher-item.active {
  border-color: var(--color-primary);
  background: #FFF0F5;
}

.switcher-lv {
  font-size: 0.65rem;
  color: var(--color-text-muted);
  font-weight: 600;
}

.switcher-add {
  width: 62px;
  justify-content: center;
  align-self: stretch;
  border: 2px dashed #ddd;
  color: var(--color-primary);
}

.switcher-add-icon {
  font-size: 1.4rem;
  font-weight: 600;
}

.pet-display {
  text-align: center;
  padding: 28px 20px;
  margin-bottom: 16px;
}

.pet-avatar {
  margin: 0 auto 16px;
}

.pet-name {
  font-size: 1.5rem;
  color: var(--color-text);
  margin-bottom: 12px;
}

.pet-level {
  display: flex;
  align-items: center;
  gap: 12px;
}

.level-badge {
  background: linear-gradient(135deg, var(--color-primary), var(--color-secondary));
  color: white;
  padding: 4px 12px;
  border-radius: var(--radius-full);
  font-size: 0.8rem;
  font-weight: 600;
  white-space: nowrap;
}

.xp-bar {
  flex: 1;
}

.xp-text {
  font-size: 0.7rem;
  color: var(--color-text-muted);
  margin-top: 4px;
  display: block;
}

.stats-grid {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-bottom: 20px;
}

.stat-item {
  display: flex;
  align-items: center;
  gap: 10px;
  background: white;
  padding: 12px 16px;
  border-radius: var(--radius-sm);
  border: 1px solid var(--color-border);
}

.stat-icon {
  font-size: 1.3rem;
}

.stat-info {
  flex: 1;
}

.stat-label {
  font-size: 0.75rem;
  color: var(--color-text-muted);
  display: block;
  margin-bottom: 4px;
}

.stat-val {
  font-size: 0.8rem;
  font-weight: 600;
  min-width: 28px;
  text-align: right;
}

.actions-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
}

.action-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  padding: 20px 12px;
  background: white;
  border: 2px solid var(--color-border);
  border-radius: var(--radius);
  transition: all 0.2s;
}

.action-btn:not(:disabled):hover {
  border-color: var(--color-primary);
  transform: translateY(-2px);
  box-shadow: var(--shadow);
}

.action-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.action-icon {
  font-size: 1.8rem;
}

.action-label {
  font-size: 0.85rem;
  font-weight: 500;
}

.action-cost {
  font-size: 0.7rem;
  color: #F57F17;
  font-weight: 500;
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

.toast.error {
  background: var(--color-danger);
}
</style>
