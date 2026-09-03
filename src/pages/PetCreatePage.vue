<template>
  <div class="create-page">
    <div class="create-header">
      <h1>{{ petStore.pets.length > 0 ? '领养新伙伴' : '选择你的宠物' }}</h1>
      <p>选一个可爱的伙伴陪伴你吧！</p>
    </div>

    <!-- 种类选择 -->
    <div class="species-grid">
      <button
        v-for="s in PET_SPECIES"
        :key="s"
        type="button"
        class="species-card"
        :class="{ selected: species === s }"
        @click="selectSpecies(s)"
      >
        <span class="species-icon-wrap">
          <img class="species-icon" :src="getPetImage(s, 4)" :alt="`${PET_SPECIES_LABELS[s]}幼年形态`" />
        </span>
        <span class="species-name">{{ PET_SPECIES_LABELS[s] }}</span>
        <span v-if="species === s" class="species-selected-mark" aria-hidden="true">✓</span>
      </button>
    </div>

    <!-- 颜色选择 -->
    <div class="section">
      <h3>选择颜色</h3>
      <PetColorPicker v-model="color" />
    </div>

    <!-- 取名 -->
    <div class="section">
      <h3>给它取个名字</h3>
      <input
        v-model="name"
        type="text"
        class="form-input"
        placeholder="输入宠物的名字"
        maxlength="10"
      />
    </div>

    <!-- 预览 -->
    <div class="preview card" v-if="species" :class="`growth-stage-${growthIndex}`" :style="getPetThemeStyle(color)">
      <div class="growth-player">
        <PetAvatar
          :key="`${species}-${growthLevel}`"
          class="preview-pet growth-enter"
          :class="{ 'growth-impact': growthIndex >= 3, 'growth-final-impact': growthIndex === 4 }"
          :species="species"
          :level="growthLevel"
          :size="growthPreviewSize"
        />
        <span class="growth-status">{{ growthStages[growthIndex].label }}</span>
      </div>
      <p class="preview-name">{{ name || '未命名' }}</p>
      <p class="preview-hint">
        {{ isPlaying ? `正在成长 · Lv.${growthLevel}` : '成长完成 · Lv.20' }}
      </p>
      <div class="growth-timeline" aria-label="宠物成长阶段">
        <span
          v-for="(stage, index) in growthStages"
          :key="stage.level"
          class="growth-step"
          :class="{ active: index === growthIndex, passed: index < growthIndex }"
        >
          <i />
          <small>{{ stage.shortLabel }}</small>
        </span>
      </div>
      <button v-if="!isPlaying" class="replay-btn" type="button" @click="playGrowth">
        ↻ 再看一次成长
      </button>
    </div>

    <p v-if="errorMsg" class="form-error">{{ errorMsg }}</p>

    <button
      class="btn btn-primary create-btn"
      :disabled="!species || !name || loading"
      @click="handleCreate"
    >
      {{ loading ? '领养中...' : '领养它！' }}
    </button>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { usePetStore } from '../stores/pet'
import { getPetImage, PET_SPECIES, PET_SPECIES_LABELS, PET_COLORS } from '../lib/constants'
import PetColorPicker from '../components/pet/PetColorPicker.vue'
import { getPetThemeStyle } from '../lib/petTheme'
import PetAvatar from '../components/pet/PetAvatar.vue'

const router = useRouter()
const petStore = usePetStore()

const species = ref('')
const color = ref(PET_COLORS[0])
const name = ref('')
const loading = ref(false)
const errorMsg = ref('')

const growthStages = [
  { level: 1, label: '宠物蛋', shortLabel: '蛋' },
  { level: 4, label: '幼年形态', shortLabel: '幼年' },
  { level: 9, label: '青年形态', shortLabel: '青年' },
  { level: 14, label: '成年形态', shortLabel: '成年' },
  { level: 20, label: '完全体', shortLabel: '完全体' },
] as const
const growthIndex = ref(0)
const growthLevel = computed(() => growthStages[growthIndex.value].level)
const growthPreviewSizes = [125, 175, 230, 300, 370] as const
const growthPreviewSize = computed(() => growthPreviewSizes[growthIndex.value])
const isPlaying = ref(false)
let growthTimer: ReturnType<typeof setTimeout> | undefined

function clearGrowthTimer() {
  if (growthTimer) clearTimeout(growthTimer)
  growthTimer = undefined
}

function playGrowth() {
  clearGrowthTimer()
  growthIndex.value = 0
  isPlaying.value = true

  const advance = () => {
    if (growthIndex.value >= growthStages.length - 1) {
      isPlaying.value = false
      growthTimer = undefined
      return
    }
    growthTimer = setTimeout(() => {
      growthIndex.value += 1
      advance()
    }, 1100)
  }
  advance()
}

function selectSpecies(selectedSpecies: string) {
  species.value = selectedSpecies
  playGrowth()
}

onBeforeUnmount(clearGrowthTimer)

onMounted(async () => {
  if (petStore.pets.length === 0) {
    await petStore.fetchPets()
  }
  if (!petStore.canAdoptNew) {
    errorMsg.value = '当前宠物尚未达到完全体（Lv.20），暂不能领养新宠物'
    setTimeout(() => router.replace('/'), 1200)
  }
})

async function handleCreate() {
  if (!species.value || !name.value) return
  errorMsg.value = ''
  loading.value = true
  const { error } = await petStore.createPet(name.value, species.value, color.value) ?? {}
  loading.value = false
  if (error) {
    errorMsg.value = error.message || '领养失败'
    return
  }
  router.push('/')
}
</script>

<style scoped>
.create-page {
  min-height: 100vh;
  padding: 32px 20px;
  max-width: 480px;
  margin: 0 auto;
}

.create-header {
  text-align: center;
  margin-bottom: 28px;
}

.create-header h1 {
  font-size: 1.8rem;
  color: var(--color-primary);
}

.create-header p {
  color: var(--color-text-muted);
  margin-top: 6px;
}

.species-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
  margin-bottom: 28px;
}

.species-card {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  min-height: 154px;
  padding: 14px 10px 13px;
  font: inherit;
  background: linear-gradient(160deg, rgba(255,255,255,0.98), rgba(255,249,246,0.92));
  border: 2px solid var(--color-border);
  border-radius: 22px;
  box-shadow: 0 7px 18px rgba(77, 55, 46, 0.07), inset 0 1px 0 white;
  cursor: pointer;
  transition: transform 0.22s ease, border-color 0.22s ease, box-shadow 0.22s ease, background 0.22s ease;
}

.species-card:hover {
  transform: translateY(-3px);
  border-color: rgba(255, 105, 155, 0.48);
  box-shadow: 0 12px 24px rgba(77, 55, 46, 0.12), inset 0 1px 0 white;
}

.species-card:focus-visible {
  outline: 3px solid rgba(255, 105, 155, 0.28);
  outline-offset: 3px;
}

.species-card.selected {
  border-color: var(--color-primary);
  background: linear-gradient(160deg, #fff7fa, #ffeaf2);
  transform: translateY(-3px);
  box-shadow: 0 14px 28px rgba(255, 105, 155, 0.2), inset 0 1px 0 white;
}

.species-icon-wrap {
  position: relative;
  display: grid;
  place-items: center;
  width: 94px;
  height: 94px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(255,255,255,0.96) 0 46%, rgba(255,224,234,0.62) 68%, transparent 72%);
}

.species-icon {
  width: 90px;
  height: 90px;
  object-fit: contain;
  filter: drop-shadow(0 6px 5px rgba(67, 43, 54, 0.18));
  transition: transform 0.25s ease, filter 0.25s ease;
}

.species-card:hover .species-icon,
.species-card.selected .species-icon {
  transform: scale(1.09) translateY(-2px);
  filter: drop-shadow(0 8px 7px rgba(67, 43, 54, 0.24));
}

.species-name {
  font-size: 0.94rem;
  font-weight: 700;
  color: var(--color-text);
}

.species-selected-mark {
  position: absolute;
  top: 9px;
  right: 9px;
  display: grid;
  place-items: center;
  width: 23px;
  height: 23px;
  border-radius: 50%;
  background: var(--color-primary);
  color: white;
  font-size: 0.74rem;
  font-weight: 900;
  box-shadow: 0 3px 8px rgba(255, 105, 155, 0.35);
}

@media (min-width: 440px) {
  .species-grid { grid-template-columns: repeat(4, minmax(0, 1fr)); }
  .species-card { min-height: 132px; padding-inline: 5px; }
  .species-icon-wrap { width: 76px; height: 76px; }
  .species-icon { width: 74px; height: 74px; }
}

.section {
  margin-bottom: 24px;
}

.section h3 {
  font-size: 1rem;
  margin-bottom: 12px;
  color: var(--color-text);
}

.preview {
  text-align: center;
  margin: 24px 0;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.72);
  box-shadow: 0 12px 28px rgba(70, 43, 62, 0.16), inset 0 1px 0 rgba(255, 255, 255, 0.72);
  transition: box-shadow 0.45s ease, transform 0.45s ease;
}

.preview.growth-stage-3 {
  box-shadow: 0 18px 38px rgba(70, 43, 62, 0.24), inset 0 1px 0 rgba(255, 255, 255, 0.8);
}

.preview.growth-stage-4 {
  box-shadow: 0 24px 52px rgba(82, 42, 116, 0.34), 0 0 0 2px rgba(255, 255, 255, 0.5), inset 0 1px 0 white;
  transform: translateY(-3px);
}

.preview-pet {
  margin: 0 auto 8px;
}

.growth-player {
  position: relative;
  min-height: 400px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.growth-player::before,
.growth-player::after {
  content: '';
  position: absolute;
  left: 50%;
  top: 50%;
  border-radius: 50%;
  transform: translate(-50%, -50%) scale(0.6);
  opacity: 0;
  pointer-events: none;
}

.growth-stage-3 .growth-player::before,
.growth-stage-4 .growth-player::before {
  width: 82%;
  aspect-ratio: 1;
  background: radial-gradient(circle, rgba(255,255,255,0.85) 0%, rgba(255,255,255,0.18) 45%, transparent 70%);
  animation: power-aura 2.2s ease-in-out infinite;
}

.growth-stage-4 .growth-player::after {
  width: 92%;
  aspect-ratio: 1;
  border: 2px solid rgba(255, 255, 255, 0.62);
  box-shadow: 0 0 28px rgba(130, 73, 190, 0.42), inset 0 0 28px rgba(255,255,255,0.28);
  animation: final-ring 2.6s ease-out infinite;
}

@media (max-width: 380px) {
  .growth-player { min-height: 340px; }
  .preview-pet { max-width: 320px; max-height: 320px; }
}

.growth-enter {
  animation: growth-appear 0.48s cubic-bezier(0.2, 0.85, 0.35, 1.25);
}

.growth-impact { animation: growth-impact 0.7s cubic-bezier(0.2, 0.85, 0.35, 1.2); }
.growth-final-impact { animation: growth-final-impact 0.9s ease-out; }

.growth-status {
  display: inline-flex;
  align-items: center;
  min-height: 24px;
  padding: 3px 10px;
  border-radius: 999px;
  background: rgba(52, 44, 49, 0.7);
  color: white;
  font-size: 0.72rem;
  font-weight: 700;
}

.preview-icon {
  font-size: 3rem;
}

.preview-name {
  font-family: var(--font-fun);
  font-size: 1.2rem;
}

.preview-hint {
  font-size: 0.72rem;
  color: var(--color-text-muted);
  margin-top: 4px;
}

.growth-timeline {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  align-items: start;
  margin: 18px auto 0;
  max-width: 360px;
}

.growth-step {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 5px;
  color: rgba(52, 44, 49, 0.5);
}

.growth-step::before {
  content: '';
  position: absolute;
  top: 5px;
  right: 50%;
  width: 100%;
  height: 3px;
  background: rgba(255, 255, 255, 0.65);
}

.growth-step:first-child::before { display: none; }

.growth-step i {
  position: relative;
  z-index: 1;
  width: 13px;
  height: 13px;
  border: 3px solid rgba(255, 255, 255, 0.85);
  border-radius: 50%;
  background: rgba(52, 44, 49, 0.28);
  transition: transform 0.25s, background 0.25s;
}

.growth-step.passed,
.growth-step.active { color: var(--color-text); }
.growth-step.passed::before,
.growth-step.active::before { background: var(--color-primary); }
.growth-step.passed i { background: var(--color-primary); }
.growth-step.active i {
  background: white;
  border-color: var(--color-primary);
  transform: scale(1.35);
  box-shadow: 0 0 0 4px rgba(255, 105, 155, 0.18);
}

.growth-step small { font-size: 0.62rem; white-space: nowrap; }

.replay-btn {
  margin-top: 14px;
  padding: 7px 14px;
  border: 0;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.7);
  color: var(--color-primary);
  font-weight: 700;
  cursor: pointer;
}

@keyframes growth-appear {
  0% { opacity: 0; transform: scale(0.72) translateY(12px); filter: brightness(1.5); }
  70% { opacity: 1; transform: scale(1.05) translateY(-3px); }
  100% { transform: scale(1) translateY(0); filter: brightness(1); }
}

@keyframes growth-impact {
  0% { opacity: 0; transform: scale(0.58) translateY(24px); filter: brightness(1.8); }
  55% { opacity: 1; transform: scale(1.1) translateY(-7px); filter: brightness(1.22); }
  78% { transform: scale(0.97) translateY(2px); }
  100% { transform: scale(1) translateY(0); filter: brightness(1); }
}

@keyframes growth-final-impact {
  0% { opacity: 0; transform: scale(0.38); filter: brightness(2.5) blur(5px); }
  42% { opacity: 1; transform: scale(1.15); filter: brightness(1.45) blur(0); }
  62% { transform: scale(0.96) rotate(-1deg); }
  78% { transform: scale(1.04) rotate(0.7deg); }
  100% { transform: scale(1) rotate(0); filter: brightness(1); }
}

@keyframes power-aura {
  0%, 100% { transform: translate(-50%, -50%) scale(0.82); opacity: 0.34; }
  50% { transform: translate(-50%, -50%) scale(1.04); opacity: 0.7; }
}

@keyframes final-ring {
  0% { transform: translate(-50%, -50%) scale(0.58); opacity: 0; }
  35% { opacity: 0.72; }
  100% { transform: translate(-50%, -50%) scale(1.06); opacity: 0; }
}

@media (prefers-reduced-motion: reduce) {
  .growth-enter { animation: none; }
  .growth-player::before,
  .growth-player::after { animation: none; }
}

.form-error {
  color: var(--color-danger, #e74c3c);
  font-size: 0.85rem;
  text-align: center;
  margin: 8px 0;
}

.create-btn {
  width: 100%;
  padding: 16px;
  font-size: 1.1rem;
}
</style>
