<template>
  <div class="adoption-fields">
    <div class="adopt-section">
      <label class="adopt-label">选择种类</label>
      <div class="species-grid">
        <button
          v-for="sp in PET_SPECIES"
          :key="sp"
          type="button"
          class="species-card"
          :class="{ selected: species === sp }"
          @click="selectSpecies(sp)"
        >
          <img class="species-icon" :src="getPetImage(sp, 4)" :alt="PET_SPECIES_LABELS[sp]" />
          <span class="species-name">{{ PET_SPECIES_LABELS[sp] }}</span>
          <span v-if="species === sp" class="selected-mark">✓</span>
        </button>
      </div>
    </div>

    <div class="adopt-section">
      <label class="adopt-label">选择颜色</label>
      <div class="color-grid">
        <button
          v-for="c in PET_COLORS"
          :key="c"
          type="button"
          class="color-dot"
          :class="{ selected: color === c }"
          :style="{ background: c }"
          :aria-label="`选择颜色 ${c}`"
          @click="color = c"
        />
      </div>
    </div>

    <div class="adopt-section">
      <label class="adopt-label">宠物名字</label>
      <input v-model="name" class="form-input" type="text" placeholder="输入宠物的名字" maxlength="10" />
    </div>

    <div v-if="species" class="pet-preview" :style="{ background: color }">
      <PetAvatar
        :key="`${species}-${previewLevel}`"
        class="preview-pet"
        :species="species"
        :level="previewLevel"
        :size="previewSize"
      />
      <div class="preview-copy">
        <span class="stage-pill">{{ stages[stageIndex].label }}</span>
        <strong>{{ name.trim() || '未命名' }}</strong>
        <small>{{ playing ? `成长预览 · Lv.${previewLevel}` : '成长预览完成 · Lv.20' }}</small>
      </div>
      <div class="preview-progress" aria-label="成长预览进度">
        <i v-for="(_, index) in stages" :key="index" :class="{ active: index <= stageIndex }" />
      </div>
      <button v-if="!playing" type="button" class="replay-button" @click="playGrowth">↻ 重播</button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'
import { getPetImage, PET_COLORS, PET_SPECIES, PET_SPECIES_LABELS } from '../../lib/constants'
import PetAvatar from './PetAvatar.vue'

const species = defineModel<string>('species', { required: true })
const color = defineModel<string>('color', { required: true })
const name = defineModel<string>('name', { required: true })

const stages = [
  { level: 1, label: '蛋' },
  { level: 4, label: '幼年' },
  { level: 9, label: '青年' },
  { level: 14, label: '成年' },
  { level: 20, label: '完全体' },
] as const
const sizes = [86, 105, 125, 148, 176] as const
const stageIndex = ref(0)
const playing = ref(false)
const previewLevel = computed(() => stages[stageIndex.value].level)
const previewSize = computed(() => sizes[stageIndex.value])
let timer: ReturnType<typeof setTimeout> | undefined

function stopTimer() {
  if (timer) clearTimeout(timer)
  timer = undefined
}

function playGrowth() {
  stopTimer()
  stageIndex.value = 0
  playing.value = true
  const advance = () => {
    if (stageIndex.value === stages.length - 1) {
      playing.value = false
      return
    }
    timer = setTimeout(() => {
      stageIndex.value += 1
      advance()
    }, 900)
  }
  advance()
}

function selectSpecies(value: string) {
  species.value = value
  playGrowth()
}

onBeforeUnmount(stopTimer)
</script>

<style scoped>
.adopt-section { margin-top: 14px; }
.adopt-label { display: block; margin-bottom: 8px; color: var(--color-text-muted); font-size: .84rem; }
.species-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 9px; }
.species-card { position: relative; display: flex; min-width: 0; flex-direction: column; align-items: center; gap: 4px; padding: 8px 3px; border: 2px solid var(--color-border); border-radius: 13px; background: white; font: inherit; cursor: pointer; transition: .2s ease; }
.species-card:hover { transform: translateY(-2px); box-shadow: 0 7px 15px rgba(65,44,54,.1); }
.species-card.selected { border-color: var(--color-primary); background: #fff0f5; box-shadow: 0 7px 16px rgba(255,105,155,.17); }
.species-icon { width: 58px; height: 58px; object-fit: contain; filter: drop-shadow(0 4px 3px rgba(55,40,48,.16)); transition: transform .2s; }
.species-card.selected .species-icon { transform: scale(1.08); }
.species-name { font-size: .74rem; color: var(--color-text); white-space: nowrap; }
.selected-mark { position: absolute; top: 4px; right: 4px; display: grid; place-items: center; width: 18px; height: 18px; border-radius: 50%; background: var(--color-primary); color: white; font-size: .65rem; }
.color-grid { display: flex; flex-wrap: wrap; gap: 10px; }
.color-dot { width: 36px; height: 36px; padding: 0; border: 3px solid transparent; border-radius: 50%; cursor: pointer; transition: .2s; }
.color-dot.selected { border-color: var(--color-text); transform: scale(1.12); box-shadow: 0 3px 8px rgba(0,0,0,.14); }
.pet-preview { position: relative; display: grid; grid-template-columns: 190px 1fr; align-items: center; min-height: 205px; margin-top: 16px; padding: 10px 18px; overflow: hidden; border: 1px solid rgba(255,255,255,.75); border-radius: 18px; box-shadow: inset 0 1px white, 0 10px 24px rgba(64,43,54,.14); }
.preview-pet { justify-self: center; animation: preview-arrive .4s ease-out; }
.preview-copy { display: flex; flex-direction: column; align-items: flex-start; gap: 7px; }
.preview-copy strong { font-size: 1.05rem; color: var(--color-text); }
.preview-copy small { color: var(--color-text-muted); }
.stage-pill { padding: 3px 9px; border-radius: 999px; background: rgba(52,44,49,.72); color: white; font-size: .7rem; font-weight: 700; }
.preview-progress { position: absolute; right: 18px; bottom: 14px; display: flex; gap: 5px; }
.preview-progress i { width: 17px; height: 4px; border-radius: 4px; background: rgba(255,255,255,.55); }
.preview-progress i.active { background: var(--color-primary); }
.replay-button { position: absolute; right: 18px; top: 14px; border: 0; border-radius: 999px; padding: 5px 9px; background: rgba(255,255,255,.7); color: var(--color-primary); cursor: pointer; }
@keyframes preview-arrive { from { opacity: 0; transform: scale(.72); } to { opacity: 1; transform: scale(1); } }
@media (max-width: 520px) {
  .species-grid { grid-template-columns: repeat(2, 1fr); }
  .pet-preview { grid-template-columns: 150px 1fr; }
}
@media (prefers-reduced-motion: reduce) { .preview-pet { animation: none; } }
</style>
