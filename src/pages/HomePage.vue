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
        <Transition name="speech-pop">
          <div v-if="petReply" class="pet-speech">{{ petReply }}</div>
        </Transition>
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

      <Teleport to="body">
        <Transition name="upgrade-showcase">
          <div v-if="levelUpEffect" class="upgrade-overlay" aria-live="polite">
            <div class="upgrade-center">
              <div class="level-up-fx" aria-hidden="true">
                <i class="fx-rays"></i><i class="fx-ring ring-one"></i><i class="fx-ring ring-two"></i>
                <b v-for="n in 16" :key="n" class="fx-particle" :style="{ '--i': n }">✦</b>
              </div>
              <PetAvatar :species="petStore.currentPet.species" :level="petStore.currentPet.level" :size="230" show-stage />
              <strong>升级成功 · Lv.{{ petStore.currentPet.level }}</strong>
            </div>
          </div>
        </Transition>
      </Teleport>

      <!-- 消息提示 -->
      <div v-if="message" class="toast" :class="{ error: isError }">{{ message }}</div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
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
const petReply = ref('')
const levelUpEffect = ref(false)
let replyTimer: ReturnType<typeof setTimeout> | undefined
let levelUpTimer: ReturnType<typeof setTimeout> | undefined
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
    if (result.success && 'reply' in result && result.reply) {
      petReply.value = result.reply
      if (replyTimer) clearTimeout(replyTimer)
      replyTimer = setTimeout(() => { petReply.value = '' }, 3200)
    }
    if (result.success && 'leveledUp' in result && result.leveledUp) {
      levelUpEffect.value = true
      if (levelUpTimer) clearTimeout(levelUpTimer)
      levelUpTimer = setTimeout(() => { levelUpEffect.value = false }, 2100)
    }
    setTimeout(() => { message.value = '' }, 2500)
  }
}

onUnmounted(() => {
  if (replyTimer) clearTimeout(replyTimer)
  if (levelUpTimer) clearTimeout(levelUpTimer)
})

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
  position: relative;
  overflow: visible;
  text-align: center;
  padding: 28px 20px;
  margin-bottom: 16px;
}

.pet-display.level-up-active { z-index: 30; }

.pet-display.level-up-active::before,
.pet-display.level-up-active::after {
  content: '';
  position: absolute;
  left: 50%;
  top: 110px;
  width: 170px;
  height: 170px;
  border-radius: 50%;
  pointer-events: none;
  transform: translate(-50%, -50%);
}

.pet-display.level-up-active::before {
  background: radial-gradient(circle, rgba(255,255,255,.98), rgba(255,232,112,.7) 35%, rgba(255,116,196,.2) 63%, transparent 73%);
  animation: home-level-glow 1.6s ease-out;
}

.pet-display.level-up-active::after {
  border: 4px solid rgba(255,242,145,.92);
  box-shadow: 0 0 28px #fff2a0, inset 0 0 24px rgba(255,255,255,.9);
  animation: home-level-ring 1.6s ease-out;
}

.pet-display.level-up-active :deep(.pet-avatar-wrap) { position: relative; z-index: 8; animation: home-level-pop 2s cubic-bezier(.2,.72,.25,1); }

.level-up-fx { position: absolute; inset: 0; z-index: 3; overflow: visible; pointer-events: none; animation: home-fx-follow 2s cubic-bezier(.2,.72,.25,1); }
.fx-rays { position: absolute; left: 50%; top: 110px; width: 220px; height: 220px; border-radius: 50%; background: repeating-conic-gradient(from 0deg, rgba(255,255,255,.98) 0 4deg, transparent 4deg 17deg), conic-gradient(#ff48ad, #fff05e, #63fff0, #8c63ff, #ff48ad); opacity: 0; mix-blend-mode: screen; transform: translate(-50%,-50%); animation: home-rays-spin 1.8s ease-out; mask: radial-gradient(circle, transparent 0 29%, #000 32% 64%, transparent 73%); }
.fx-ring { position: absolute; left: 50%; top: 110px; width: 135px; height: 135px; border: 5px solid white; border-radius: 50%; box-shadow: 0 0 14px white, 0 0 32px #ffe76c, 0 0 52px #ff5fc5; transform: translate(-50%,-50%); }
.ring-one { animation: home-ring-burst 1.65s ease-out forwards; }
.ring-two { border-color: #79fff1; animation: home-ring-burst 1.65s .17s ease-out forwards; }
.fx-particle { --angle: calc(var(--i) * 22.5deg); position: absolute; left: 50%; top: 110px; color: #fff8a8; font-size: 24px; text-shadow: 0 0 7px white, 0 0 15px #ff49bb; opacity: 0; animation: home-particle-fly 1.6s calc(var(--i) * 18ms) cubic-bezier(.12,.7,.2,1) forwards; }

@keyframes home-level-glow { 0% { opacity: 0; transform: translate(-50%, -50%) scale(.3); } 28% { opacity: 1; } 100% { opacity: 0; transform: translate(-50%, -50%) scale(1.8); } }
@keyframes home-level-ring { 0% { opacity: 0; transform: translate(-50%, -50%) scale(.5); } 24% { opacity: 1; } 100% { opacity: 0; transform: translate(-50%, -50%) scale(1.65); } }
@keyframes home-level-pop {
  0% { transform: translateY(0) scale(1); filter: brightness(1); }
  12% { transform: translateY(10px) scale(.93); }
  28% { transform: translateY(-112px) scale(1.48); filter: brightness(1.68) saturate(1.5) drop-shadow(0 0 30px #fff3a3); }
  58% { transform: translateY(-126px) scale(1.58) rotate(-2deg); filter: brightness(1.45) saturate(1.7) drop-shadow(0 0 38px #ff65c7); }
  72% { transform: translateY(-112px) scale(1.48) rotate(2deg); }
  90% { transform: translateY(7px) scale(.98); filter: brightness(1.08); }
  100% { transform: translateY(0) scale(1); filter: brightness(1); }
}
@keyframes home-rays-spin { 0% { opacity: 0; transform: translate(-50%,-50%) scale(.15) rotate(0); } 24% { opacity: .95; } 100% { opacity: 0; transform: translate(-50%,-50%) scale(1.8) rotate(170deg); } }
@keyframes home-ring-burst { 0% { opacity: 0; transform: translate(-50%,-50%) scale(.2); } 25% { opacity: 1; } 100% { opacity: 0; transform: translate(-50%,-50%) scale(2); } }
@keyframes home-particle-fly { 0% { opacity: 0; transform: translate(-50%,-50%) rotate(var(--angle)) translateY(0) scale(.3); } 18% { opacity: 1; } 76% { opacity: 1; } 100% { opacity: 0; transform: translate(-50%,-50%) rotate(var(--angle)) translateY(-132px) scale(1.35); } }
@keyframes home-fx-follow { 0%, 12%, 100% { transform: translateY(0); } 28%, 72% { transform: translateY(-112px); } 58% { transform: translateY(-126px); } 90% { transform: translateY(7px); } }

.pet-speech {
  position: absolute;
  top: 28px;
  left: calc(50% + 54px);
  z-index: 3;
  max-width: 150px;
  padding: 9px 12px;
  border: 1px solid rgba(255, 105, 155, .22);
  border-radius: 14px 14px 14px 5px;
  background: rgba(255, 255, 255, .95);
  color: #6b3b4d;
  font-size: .78rem;
  line-height: 1.4;
  text-align: left;
  box-shadow: 0 7px 18px rgba(94, 50, 67, .15);
}

.pet-speech::after {
  content: '';
  position: absolute;
  left: 10px;
  bottom: -7px;
  border-width: 7px 7px 0 0;
  border-style: solid;
  border-color: rgba(255, 255, 255, .95) transparent transparent transparent;
}

.speech-pop-enter-active, .speech-pop-leave-active { transition: opacity .2s ease, transform .2s ease; }
.speech-pop-enter-from, .speech-pop-leave-to { opacity: 0; transform: translateY(5px) scale(.94); }

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

.upgrade-overlay { position: fixed; inset: 0; z-index: 1000; display: grid; place-items: center; overflow: hidden; background: radial-gradient(circle at center, rgba(74,35,91,.18), rgba(24,13,31,.64)); backdrop-filter: blur(4px); pointer-events: none; }
.upgrade-center { position: relative; display: flex; width: 360px; height: 410px; flex-direction: column; align-items: center; justify-content: center; color: white; text-align: center; text-shadow: 0 2px 10px rgba(64,20,72,.55); }
.upgrade-center > :deep(.pet-avatar-wrap) { position: relative; z-index: 8; animation: center-pet-upgrade 2s cubic-bezier(.2,.72,.25,1); }
.upgrade-center > strong { position: relative; z-index: 9; margin-top: 22px; padding: 8px 20px; border: 1px solid rgba(255,255,255,.68); border-radius: 999px; background: rgba(117,56,138,.64); font-size: 1.08rem; box-shadow: 0 0 28px rgba(255,111,210,.6); animation: upgrade-title-in 2s ease both; }
.upgrade-center .level-up-fx { inset: 0; animation: none; }
.upgrade-center .fx-rays, .upgrade-center .fx-ring, .upgrade-center .fx-particle { top: 46%; }
.upgrade-showcase-enter-active, .upgrade-showcase-leave-active { transition: opacity .2s ease; }
.upgrade-showcase-enter-from, .upgrade-showcase-leave-to { opacity: 0; }
@keyframes center-pet-upgrade { 0% { opacity: 0; transform: translateY(160px) scale(.5); filter: brightness(1); } 24% { opacity: 1; transform: translateY(-28px) scale(1.2); filter: brightness(1.75) saturate(1.55) drop-shadow(0 0 34px #fff3a3); } 55% { transform: translateY(-44px) scale(1.32) rotate(-2deg); filter: brightness(1.48) saturate(1.75) drop-shadow(0 0 48px #ff65c7); } 72% { transform: translateY(-30px) scale(1.22) rotate(2deg); } 100% { opacity: 1; transform: translateY(0) scale(1); filter: brightness(1); } }
@keyframes upgrade-title-in { 0%, 25% { opacity: 0; transform: translateY(15px) scale(.84); } 45%, 88% { opacity: 1; transform: translateY(0) scale(1); } 100% { opacity: 0; } }
</style>
