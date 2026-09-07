<template>
  <svg viewBox="0 0 32 32" aria-hidden="true" :style="{ color: `var(--pet-control-ink, ${mark.ink})` }">
    <g fill="currentColor" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
      <g v-if="mark.kind === 'rabbit'" stroke="none">
        <ellipse cx="11" cy="10" rx="4" ry="9" transform="rotate(-12 11 10)"/><ellipse cx="21" cy="10" rx="4" ry="9" transform="rotate(12 21 10)"/>
        <ellipse cx="16" cy="23" rx="11" ry="8"/><path d="M10 6v8m12-8v8" stroke="#fff" stroke-width="2" opacity=".6"/>
      </g>
      <g v-else-if="mark.kind === 'shell'" stroke-width="2">
        <ellipse cx="16" cy="17" rx="11" ry="12"/><path d="m16 9 6 4v7l-6 4-6-4v-7zm0 0V5m6 8 4-2m-4 9 4 3m-10 1v5m-6-9-4 3m4-10-4-2" fill="none" stroke="#fff" opacity=".7"/>
      </g>
      <g v-else-if="mark.kind === 'feather'" stroke-width="2">
        <path d="M8 25C0 11 16 1 27 4c1 13-8 24-19 21Z"/><path d="M5 29 23 8m-11 13-1-7m7 0 6 1" fill="none" stroke="#fff" opacity=".8"/>
      </g>
      <g v-else-if="mark.kind === 'fish'" stroke="none">
        <path d="M25 16C20 3 8 6 4 16c4 10 16 13 21 0Z"/><path d="m23 16 7-7v14Z"/><circle cx="10" cy="14" r="1.5" fill="#fff"/>
      </g>
      <g v-else-if="mark.kind === 'nut'" stroke-width="2">
        <path d="M7 14c0 10 5 13 9 16 4-3 9-6 9-16Z"/><path d="M5 14C5 4 27 4 27 14Z" fill="#fff" fill-opacity=".5"/><path d="M16 6c0-3 2-4 4-4" fill="none"/>
      </g>
      <g v-else-if="mark.kind === 'flame'" stroke="none">
        <path d="M17 2c3 10 12 10 11 19C26 35 4 33 4 20c0-5 3-9 7-12-1 5 0 7 2 8 4-4 5-9 4-14Z"/><path d="M16 16c0 5-6 7-4 11 3 4 10 1 8-3Z" fill="#fff" opacity=".65"/>
      </g>
      <g v-else stroke="none">
        <ellipse cx="7" cy="12" rx="3.5" ry="4.5" transform="rotate(-25 7 12)"/><ellipse cx="13" cy="7" rx="3.3" ry="4.5"/><ellipse cx="21" cy="8" rx="3.3" ry="4.5" transform="rotate(15 21 8)"/><ellipse cx="27" cy="14" rx="3.3" ry="4.3" transform="rotate(30 27 14)"/>
        <path d="M7 24c0-4 6-11 10-11s10 8 10 12c0 7-7 4-10 4S7 32 7 24Z"/>
        <ellipse cx="13" cy="23" rx="2" ry="1.5" fill="#fff" opacity=".45"/>
      </g>
    </g>
  </svg>
</template>
<script setup lang="ts">
import { computed } from 'vue'
import { petControlTheme } from '../../lib/petControlTheme'
const props = defineProps<{ species: string }>()
const mark = computed(() => petControlTheme(props.species))
</script>
