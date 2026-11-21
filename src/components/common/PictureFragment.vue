<template>
  <polygon :points="points" :fill="color" stroke="#253754" stroke-opacity=".4" />
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { Point } from '../../lib/geometryGame'

const props = defineProps<{ vertices: Point[]; color: string }>()
const points = computed(() => props.vertices.map(point => point.join(',')).join(' '))
</script>
