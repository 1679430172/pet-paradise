<template>
  <g>
    <defs>
      <clipPath :id="clipId">
        <polygon :points="points" />
      </clipPath>
    </defs>
    <image :href="picture" x="-112" y="-80" width="224" height="160"
      preserveAspectRatio="xMidYMid slice" :clip-path="`url(#${clipId})`" pointer-events="none" />
    <polygon :points="points" fill="transparent" stroke="#253754" stroke-opacity=".4" />
  </g>
</template>

<script setup lang="ts">
import { computed, useId } from 'vue'
import type { Point } from '../../lib/geometryGame'

const props = defineProps<{ vertices: Point[]; picture: string }>()
const clipId = `picture-fragment-${useId()}`
const points = computed(() => props.vertices.map(point => point.join(',')).join(' '))
</script>
