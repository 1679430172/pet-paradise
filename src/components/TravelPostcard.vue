<template>
  <article class="postcard" :class="destinationId">
    <div class="picture">
      <img v-if="postcardArt(destinationId, story)" :src="postcardArt(destinationId, story)" :alt="story" loading="lazy" decoding="async" width="960" height="480" />
      <span class="picture-label">{{ name }}</span>
      <span class="edition">No. {{ String(number).padStart(2, '0') }}</span>
    </div>
    <div class="letter">
      <div class="letter-top"><span>亲爱的你：</span><div class="postmark" aria-hidden="true">PET POST<em>{{ icon }}</em>远方来信</div></div>
      <p>{{ story }}</p>
      <footer><span>{{ source === 'gift' || (!source && !petName) ? '纪念版 · 无出游宠物' : petSnapshot ? '出发时 · ' + stageLabel : '旧旅行 · 当时形态未记录' }}</span><span class="signature">{{ petSnapshot?.name || petName || '远方来信' }}{{ petName || petSnapshot ? ' 寄' : '' }}</span></footer>
    </div>
  </article>
</template>

<script setup lang="ts">
import { postcardArt } from '../lib/travelArt'
import { computed } from 'vue'
import type { TravelPetSnapshot } from '../stores/travel'
import { PET_STAGE_LABELS } from '../lib/constants'
const props = defineProps<{ destinationId: string; name: string; icon: string; story: string; number: number; petSnapshot?: TravelPetSnapshot | null; petName?: string | null; source?: string }>()
const stageLabel = computed(() => props.petSnapshot ? PET_STAGE_LABELS[props.petSnapshot.stage] : '')
</script>

<style scoped>
.postcard{--accent:#577564;--sky:#e4e9cc;--sun:#fff4cc;background:#fffdf7;border:1px solid #e6dece;border-radius:7px;overflow:hidden;box-shadow:0 4px 12px #65533409;display:flex;flex-direction:column;padding:10px;min-width:0}
.coast{--accent:#487d87;--sky:#c7e6e7;--sun:#fff2d3}.stars{--accent:#72648c;--sky:#353e61;--sun:#f5e3b5}
.picture{position:relative;overflow:hidden;border-radius:3px;height:auto;aspect-ratio:2 / 1;flex-shrink:0;background:var(--sky)}
img{width:100%;height:100%;object-fit:cover;display:block}
.picture:after{content:"";position:absolute;inset:60% 0 0;background:linear-gradient(transparent,#1b354c99);pointer-events:none}.picture-label,.edition{z-index:1;position:absolute;bottom:12px;color:white;text-shadow:0 1px 4px #263d3dcc;font-size:.75rem;letter-spacing:.12em}.picture-label{left:14px;font-weight:650}.edition{right:12px;font-size:.65rem;font-variant-numeric:tabular-nums}
.letter{padding:18px 12px 8px;display:flex;flex-direction:column;flex:1;background-image:radial-gradient(#aa956e18 .6px,transparent .6px);background-size:5px 5px}
.letter-top{display:flex;justify-content:space-between;align-items:center;height:46px;color:var(--accent);font-size:.78rem;letter-spacing:.08em}
.postmark{width:58px;height:58px;border:1px dashed currentColor;outline:1px solid currentColor;outline-offset:-4px;border-radius:50%;display:flex;flex-direction:column;align-items:center;justify-content:center;font-size:7px;letter-spacing:.05em;transform:rotate(12deg);opacity:.75;flex-shrink:0}.postmark em{font-size:17px;font-style:normal;line-height:1.4}
p{font-size:.88rem;line-height:2.05;color:#4e5c54;margin:17px 0 22px;overflow-wrap:anywhere}
footer{display:flex;justify-content:space-between;align-items:center;gap:8px;margin-top:auto;border-top:1px dashed #d8d1c1;padding-top:13px;font-size:.65rem;color:#887e6b}.signature{color:var(--accent);font-size:.72rem}
@media(max-width:600px){.picture{height:auto}.letter{padding:18px 16px 10px}}
</style>
