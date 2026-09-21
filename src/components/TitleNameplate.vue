<template>
  <span
    v-if="title"
    class="title-effect is-alternating"
    :class="`title-effect--${titleTheme(title)}`"
    :aria-label="`${name}，称号 ${title}`"
    :title="`${name} · ${title}`"
  >
    <span class="title-effect__name">{{ name }}</span>
    <span class="title-effect__title">{{ title }}</span>
  </span>
  <span v-else>{{ name }}</span>
</template>

<script setup lang="ts">
import { titleTheme } from '../lib/studentTitles'

defineProps<{
  name: string
  title?: string | null
}>()
</script>
