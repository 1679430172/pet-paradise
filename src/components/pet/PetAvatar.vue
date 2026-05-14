<template>
  <div
    class="pet-avatar-wrap"
    :class="{ 'is-empty': empty }"
    :style="wrapStyle"
  >
    <img
      v-if="!empty && !imgError"
      :src="imgSrc"
      :alt="species"
      class="pet-avatar-img"
      @error="imgError = true"
    />
    <span v-else-if="empty" class="pet-avatar-fallback" :style="emojiStyle">🥚</span>
    <span v-else class="pet-avatar-fallback" :style="emojiStyle">{{ speciesEmoji }}</span>

    <span v-if="showStage && !empty" class="pet-avatar-stage">{{ stageLabel }}</span>
  </div>
</template>


<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { getPetImage, getPetStage, PET_STAGE_LABELS, PET_SPECIES } from '../../lib/constants'

interface Props {
  species?: string
  level?: number
  size?: number
  bgColor?: string
  border?: boolean
  showStage?: boolean
  empty?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  species: '',
  level: 1,
  size: 68,
  bgColor: '',
  border: true,
  showStage: false,
  empty: false,
})

const imgError = ref(false)

watch(() => [props.species, props.level], () => { imgError.value = false })

const imgSrc = computed(() => getPetImage(props.species || PET_SPECIES[0], props.level || 1))

const stageLabel = computed(() => PET_STAGE_LABELS[getPetStage(props.level || 1)])

// 各种类 emoji 备选（图片加载失败时展示），未配置的种类统一用 🐾
const SPECIES_EMOJI: Record<string, string> = {
  紫电龙: '🐉',
}
const speciesEmoji = computed(() => SPECIES_EMOJI[props.species] || '🐾')

// 不再作为“头像”：去除圆形/背景/描边，直接展示宠物图片
// bgColor / border props 保留是为了兼容旧调用，但不再应用到样式上
const wrapStyle = computed(() => ({
  width: props.size + 'px',
  height: props.size + 'px',
  background: props.empty ? 'rgba(0,0,0,0.04)' : 'transparent',
  border: props.empty ? '2px dashed rgba(0,0,0,0.15)' : 'none',
  borderRadius: props.empty ? '50%' : '0',
}))

const emojiStyle = computed(() => ({
  fontSize: Math.round(props.size * 0.5) + 'px',
}))
</script>

<style scoped>
.pet-avatar-wrap {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  box-sizing: border-box;
  flex-shrink: 0;
}

.pet-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
  pointer-events: none;
  user-select: none;
}

.pet-avatar-fallback {
  line-height: 1;
}

.pet-avatar-wrap.is-empty .pet-avatar-fallback {
  opacity: 0.6;
}

.pet-avatar-stage {
  position: absolute;
  bottom: 2px;
  left: 50%;
  transform: translateX(-50%);
  background: rgba(0, 0, 0, 0.55);
  color: #fff;
  font-size: 0.6rem;
  padding: 1px 6px;
  border-radius: 8px;
  white-space: nowrap;
}
</style>
