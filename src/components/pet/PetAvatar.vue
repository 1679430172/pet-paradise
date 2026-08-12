<template>
  <div
    class="pet-avatar-wrap"
    :class="[{ 'is-empty': empty }, `stage-${stage}`]"
    :style="wrapStyle"
  >
    <picture v-if="!empty && !imgError" class="pet-avatar-picture">
      <source media="(prefers-reduced-motion: reduce)" :srcset="imgSrc" />
      <source type="image/webp" :srcset="animatedSrc" />
      <img
        :src="imgSrc"
        :alt="species"
        class="pet-avatar-img"
        @error="imgError = true"
      />
    </picture>
    <span v-else-if="empty" class="pet-avatar-fallback" :style="emojiStyle">🥚</span>
    <span v-else class="pet-avatar-fallback" :style="emojiStyle">{{ speciesEmoji }}</span>

    <span v-if="showStage && !empty" class="pet-avatar-stage">{{ stageLabel }}</span>
  </div>
</template>


<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { getPetAnimation, getPetImage, getPetStage, PET_STAGE_LABELS, PET_SPECIES } from '../../lib/constants'

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
const animatedSrc = computed(() => getPetAnimation(props.species || PET_SPECIES[0], props.level || 1))

const stageLabel = computed(() => PET_STAGE_LABELS[getPetStage(props.level || 1)])
const stage = computed(() => getPetStage(props.level || 1))

// 各种类 emoji 备选（图片加载失败时展示），未配置的种类统一用 🐾
const SPECIES_EMOJI: Record<string, string> = {
  紫电龙: '🐉',
  星焰狐: '🦊',
  云朵猫: '🐱',
  碧海龟: '🐢',
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
  isolation: isolate;
  overflow: visible;
}

.pet-avatar-wrap::before {
  content: '';
  position: absolute;
  z-index: -1;
  left: 50%;
  top: 54%;
  width: 76%;
  height: 58%;
  border-radius: 50%;
  background: radial-gradient(ellipse, rgba(255, 255, 255, 0.72) 0%, rgba(255, 255, 255, 0.2) 48%, transparent 72%);
  transform: translate(-50%, -50%);
  filter: blur(5px);
  pointer-events: none;
}

.pet-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
  pointer-events: none;
  user-select: none;
  transform-origin: 50% 82%;
  filter: drop-shadow(0 7px 7px rgba(56, 36, 52, 0.2));
}

.pet-avatar-picture {
  display: block;
  width: 100%;
  height: 100%;
  transform-origin: 50% 82%;
  animation: pet-breathe 2.8s ease-in-out infinite;
  will-change: transform;
}

.stage-egg::before { width: 48%; height: 38%; opacity: 0.55; }
.stage-baby::before { width: 60%; height: 46%; }
.stage-teen::before { width: 70%; height: 52%; }
.stage-adult::before { width: 82%; height: 62%; }
.stage-final::before {
  width: 104%;
  height: 88%;
  opacity: 0.9;
  background: radial-gradient(ellipse, rgba(224, 201, 255, 0.75) 0%, rgba(164, 112, 238, 0.3) 48%, transparent 74%);
  animation: final-aura 2.6s ease-in-out infinite;
}

.stage-egg .pet-avatar-img { filter: drop-shadow(0 4px 4px rgba(56, 36, 52, 0.16)); }
.stage-teen .pet-avatar-img { filter: drop-shadow(0 8px 8px rgba(56, 36, 52, 0.23)); }
.stage-adult .pet-avatar-img { filter: drop-shadow(0 9px 9px rgba(56, 36, 52, 0.26)); }
.stage-final .pet-avatar-img { filter: drop-shadow(0 11px 10px rgba(56, 36, 52, 0.28)) drop-shadow(0 0 7px rgba(139, 92, 246, 0.4)); }

.pet-avatar-wrap:hover .pet-avatar-img { animation: pet-greet 0.55s ease-in-out; }

/* 独立于动态 WebP 的基础呼吸效果，CDN 或浏览器只显示静态帧时仍然生效。 */
@keyframes pet-breathe {
  0%, 100% { transform: translateY(0) scale(1, 1); }
  50% { transform: translateY(-1.8%) scale(1.025, 1.045); }
}

@keyframes final-aura {
  0%, 100% { transform: translate(-50%, -50%) scale(0.94); opacity: 0.62; }
  50% { transform: translate(-50%, -50%) scale(1.08); opacity: 0.95; }
}

@keyframes pet-greet {
  0%, 100% { transform: translateY(0) rotate(0); }
  35% { transform: translateY(-7%) rotate(-3deg) scale(1.04); }
  70% { transform: translateY(-2%) rotate(3deg) scale(1.02); }
}

@media (prefers-reduced-motion: reduce) {
  .pet-avatar-picture { animation: none !important; }
  .pet-avatar-img { animation: none !important; }
  .pet-avatar-wrap::before { animation: none !important; }
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
