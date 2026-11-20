<template>
  <canvas ref="canvas" width="544" height="208" aria-hidden="true"></canvas>
</template>

<script setup lang="ts">
import { ref, watchEffect } from 'vue'
import { add, scale, sub } from '../../lib/geometryGame'
import type { Point } from '../../lib/geometryGame'
import type { GeometryCutRecord } from '../../lib/geometryCutRecords'

const props = defineProps<{ record: GeometryCutRecord }>()
const canvas = ref<HTMLCanvasElement>()
watchEffect(() => {
  const ctx = canvas.value?.getContext('2d')
  if (!ctx) return
  const { before, pieces, edge, color } = props.record
  const xs = before.map(point => point[0])
  const ys = before.map(point => point[1])
  const left = Math.min(...xs)
  const top = Math.min(...ys)
  const width = Math.max(...xs) - left
  const height = Math.max(...ys) - top
  const center: Point = [left + width / 2, top + height / 2]
  const ratio = 70 / Math.max(width, height, 1e-7)
  const [x, y] = sub(edge.to, edge.from)
  const lift = scale([-y, x], 6 / Math.max(Math.hypot(x, y), 1e-7))
  const project = (point: Point, origin: Point) => add(origin, scale(sub(point, center), ratio))
  const first: Point = [66, 52]
  const second: Point = [206, 52]
  ctx.setTransform(2, 0, 0, 2, 0, 0)
  ctx.clearRect(0, 0, 272, 104)

  function drawPolygon(vertices: Point[], origin: Point) {
    if (!ctx) return
    ctx.beginPath()
    vertices.forEach((point, index) => {
      const position = project(point, origin)
      if (index === 0) ctx.moveTo(...position)
      else ctx.lineTo(...position)
    })
    ctx.closePath()
    ctx.fillStyle = color
    ctx.fill()
    ctx.lineWidth = 1.5
    ctx.strokeStyle = '#526078'
    ctx.stroke()
  }
  drawPolygon(before, first)
  drawPolygon(pieces[0], add(second, lift))
  drawPolygon(pieces[1], sub(second, lift))

  ctx.beginPath()
  ctx.moveTo(...project(edge.from, first))
  ctx.lineTo(...project(edge.to, first))
  ctx.setLineDash([4, 3])
  ctx.strokeStyle = '#086e70'
  ctx.lineWidth = 2
  ctx.stroke()
  ctx.setLineDash([])
  ctx.fillStyle = '#526078'
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  ctx.font = 'bold 20px sans-serif'
  ctx.fillText('→', 136, 52)
})
</script>

<style scoped>
canvas { display: block; width: 100%; height: auto; background: #f4f7fe; border-radius: 10px; }
</style>
