<template>
  <main class="geometry-page">
    <header class="game-header">
      <div class="game-title">
        <span class="logo" aria-hidden="true">✂</span>
        <div><h1>几何切切乐</h1><p>选两个点，把彩纸图形剪成两块。</p></div>
      </div>
      <div class="paper-art" aria-hidden="true"><i></i><i></i><i></i></div>
    </header>

    <div class="game-layout">
      <section class="workspace" aria-label="平面工作台">
        <div class="workspace-header">
          <div class="tool-group" aria-label="操作工具">
            <button v-for="tool in tools" :key="tool.key" class="tool" :data-tool="tool.key" :aria-pressed="mode === tool.key" @click="setMode(tool.key)">
              <span aria-hidden="true">{{ tool.icon }}</span>{{ tool.label }}
            </button>
          </div>
          <div class="view-tools" aria-label="视图">
            <button aria-label="缩小" @click="changeZoom(-1)">−</button>
            <button title="让所有图形回到视野内" @click="fitView">看全部</button>
            <button aria-label="放大" @click="changeZoom(1)">＋</button>
          </div>
        </div>

        <ol class="cut-steps" :data-tool="mode" :aria-label="tutorials[mode].label">
          <li v-for="(step, index) in tutorials[mode].steps" :key="step.title" :aria-current="mode === 'cut' && active && cutStep === index ? 'step' : undefined" :class="{ done: mode === 'cut' && !!active && cutStep > index }">
            <div v-if="mode === 'cut'" class="step-picture" :data-step="index" aria-hidden="true">
              <i class="step-paper"></i>
              <i v-if="index === 2" class="step-paper second"></i>
              <i v-if="index === 1" class="step-line"></i>
              <i v-if="index < 2" class="step-dot">1</i>
              <i v-if="index === 1" class="step-dot second">2</i>
              <i v-if="index === 2" class="step-scissors">✂</i>
            </div>
            <div v-else class="step-picture" :data-step="index" aria-hidden="true">
              <i class="step-paper"></i>
              <i v-if="mode === 'move' && index === 2" class="step-paper second"></i>
              <i v-if="mode === 'rotate'" class="step-pivot"></i>
              <i class="step-symbol">{{ step.symbol }}</i>
            </div>
            <div class="step-copy">
              <strong>{{ step.title }}</strong>
              <span>{{ step.hint }}</span>
            </div>
          </li>
        </ol>
        <div class="stage" :data-mode="mode" :style="gridPosition">
          <canvas ref="canvas" class="work-canvas" aria-label="平面图形画布" aria-describedby="geometry-instruction" @pointerdown="startDrag" @pointermove="drag" @pointerup="finishDrag" @pointercancel="cancelDrag" @lostpointercapture="cancelDrag" />
          <p v-if="!solids.length" class="stage-empty">选一张彩纸，放到这里</p>
          <span class="view-note">{{ solids.length }} 个图形</span>
        </div>

        <div class="workspace-footer">
          <div class="workspace-message" aria-live="polite">
            <strong v-if="feedback && !cutAnimation" class="feedback">{{ feedback }}</strong>
            <span id="geometry-instruction">{{ instruction }}</span>
          </div>
          <button class="cut-button" :class="{ 'reserved-cut-button': mode !== 'cut' }" :aria-hidden="mode !== 'cut'" :disabled="!cutResult || !!cutAnimation || !!liveLine" @click="cut">
            <span aria-hidden="true">✂</span> 确认切割
          </button>
        </div>
      </section>

      <section class="panel palette">
        <h2>添加图形</h2>
        <div class="shape-list">
          <button v-for="shape in shapes" :key="shape.key" :class="shape.key" :style="{ '--paper': shape.color, '--paper-light': shape.tint }" @click="spawn(shape.key)">
            <span class="shape-icon" :class="shape.key" aria-hidden="true"></span>
            <span>{{ shape.label }}</span><span class="add-shape" aria-hidden="true">＋</span>
          </button>
        </div>
      </section>

      <section class="panel cut-panel">
        <h2>{{ tutorials[mode].tipTitle }}</h2>
        <p>{{ mode === 'cut' ? cutStatus : tutorials[mode].tip }}</p>
        <div v-if="mode === 'cut' && cutAngle" class="snap-list">
          <span>相对边 {{ cutAngle.degrees }}°</span>
          <span v-if="cutAngle.snapped">角度吸附</span>
          <span v-if="centerSnapped">中线吸附</span>
          <span v-if="midpointSnapped">边中点吸附</span>
          <span v-if="vertexSnapped">顶点吸附</span>
        </div>
        <button v-if="mode === 'cut' && (firstCutPoint || cutLine)" class="quiet-button" @click="clearCutPoints">重新选点</button>
      </section>

      <section class="panel board-actions" aria-label="画布管理">
        <div class="tool-group">
          <button class="quiet-button" :disabled="!history.length" @click="undo">↶ 撤销</button>
          <button class="quiet-button delete-button" :disabled="!active" @click="deleteSelected">删除选中图形</button>
          <button class="quiet-button" @click="reset()">重置画布</button>
        </div>
      </section>

      <section class="panel cut-records" aria-labelledby="cut-records-title">
        <header class="records-header">
          <h2 id="cut-records-title">我的切割记录</h2>
          <span v-if="cutRecords.length">最近 {{ cutRecords.length }} 刀</span>
        </header>
        <p v-if="recordsSaveFailed" class="records-message" role="status">浏览器暂时无法保存记录，刷新后可能会丢失。</p>
        <p v-if="!cutRecords.length" class="records-message">剪开第一张彩纸后，就能在这里看到切割前后的样子。</p>
        <ol v-else class="record-list">
          <li v-for="record in visibleRecords" :key="record.id">
            <GeometryCutThumbnail :record="record" />
            <div class="record-caption"><span>切割前</span><span>切割后</span></div>
            <div class="record-details">
              <strong>{{ geometryShapeName(record.before) }} → {{ geometryShapeName(record.pieces[0]) }} ＋ {{ geometryShapeName(record.pieces[1]) }}</strong>
              <time :datetime="new Date(record.timestamp).toISOString()">{{ recordDate.format(record.timestamp) }}</time>
            </div>
          </li>
        </ol>
        <button v-if="visibleRecords.length < cutRecords.length" class="quiet-button" @click="visibleRecordLimit += 6">查看更多记录</button>
      </section>
    </div>
  </main>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, shallowRef, watch, watchEffect } from 'vue'
import { add, center, cross, cutAngleToEdges, distanceToLine, findEdgeSnap, makeShape, polygonCentroid, polygonEdges, scale, snapCutDirection, snapCutEndpointToPoint, snapCutLineToPoint, snapRotationToAxes, splitPolygon, sub } from '../lib/geometryGame'
import type { Line, Point, Shape } from '../lib/geometryGame'
import GeometryCutThumbnail from '../components/common/GeometryCutThumbnail.vue'
import { cutRecordLimit, geometryShapeName, readCutRecords, saveCutRecords } from '../lib/geometryCutRecords'
import type { GeometryCutRecord } from '../lib/geometryCutRecords'
import { randomUuid } from '../lib/uuid'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const cutRecords = shallowRef<GeometryCutRecord[]>([])
const recordKey = computed(() => auth.user ? `geometry-cut-records:${auth.user.id}` : '')
const visibleRecordLimit = ref(6)
const visibleRecords = computed(() => cutRecords.value.slice(0, visibleRecordLimit.value))
const recordsSaveFailed = ref(false)
const recordDate = new Intl.DateTimeFormat('zh-CN', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Shanghai' })
watch(recordKey, key => {
  cutRecords.value = key ? readCutRecords(key) : []
  visibleRecordLimit.value = 6
  recordsSaveFailed.value = false
}, { immediate: true })

function updateCutRecords(records: GeometryCutRecord[]) {
  cutRecords.value = records.slice(0, cutRecordLimit)
  if (recordKey.value) recordsSaveFailed.value = !saveCutRecords(recordKey.value, cutRecords.value)
}

type Piece = { id: number; vertices: Point[]; color: string }
type Mode = 'move' | 'rotate' | 'cut'
type CutAnimation = {
  previous: Piece[]
  originalId: number
  firstId: number
  secondId: number
  offset: Point
  edge: Line
  elapsed: number
}
const cutStrokeDuration = 320
const cutSeparationDuration = 680
const confettiColors = ['#e36b99', '#6550c3', '#d99519', '#218c75']
const cutAnimation = shallowRef<CutAnimation>()
let cutAnimationFrame: number | undefined
const shapes: { key: Shape; label: string; color: string; tint: string }[] = [
  { key: 'square', label: '正方形', color: '#f6c853', tint: '#fff5d8' },
  { key: 'rectangle', label: '长方形', color: '#79cdb9', tint: '#eaf9f3' },
  { key: 'triangle', label: '三角形', color: '#ec98b8', tint: '#ffedf4' },
]
const tools: { key: Mode; label: string; icon: string }[] = [
  { key: 'cut', label: '切割', icon: '✂' },
  { key: 'move', label: '移动', icon: '✥' },
  { key: 'rotate', label: '旋转', icon: '⟳' },
]
const canvas = ref<HTMLCanvasElement>()
const viewport = ref({ width: 0, height: 0 })
const solids = shallowRef<Piece[]>([])
const selected = ref<number>()
const active = computed(() => solids.value.find(piece => piece.id === selected.value))
const cutCenter = computed(() => active.value && polygonCentroid(active.value.vertices))
const edgeMidpoints = computed(() => active.value
  ? polygonEdges(active.value.vertices).map(({ from, to }) => scale(add(from, to), 0.5))
  : [])
const snapPoints = computed(() => [
  ...(active.value?.vertices ?? []).map(point => ({ point, vertex: true })),
  ...edgeMidpoints.value.map(point => ({ point, vertex: false })),
])
const firstCutPoint = shallowRef<Point>()
const mode = ref<Mode>('cut')
watch([active, mode], () => { firstCutPoint.value = undefined }, { flush: 'sync' })
const feedback = ref('')
const cutLine = shallowRef<Line>()
const liveLine = shallowRef<Line>()
const moveSeam = shallowRef<Line>()
const rotationGuide = shallowRef<{ edge: Line; label: string }>()
const camera = shallowRef<Point>([0, 0])
const zoomFactor = ref(1)
const baseZoom = computed(() => Math.min(viewport.value.width, viewport.value.height) / 4.4)
const zoom = computed(() => baseZoom.value * zoomFactor.value)
const gridPosition = computed(() => ({
  '--grid-x': `${-camera.value[0] * zoom.value}px`,
  '--grid-y': `${-camera.value[1] * zoom.value}px`,
}))
const displayedLine = computed(() => liveLine.value ?? cutLine.value)
const centerSnapped = computed(() => {
  const line = displayedLine.value
  const point = cutCenter.value
  return !!line && !!point && Math.abs(distanceToLine(line, point)) * zoom.value < 0.001
})
const midpointSnapped = computed(() => {
  const line = displayedLine.value
  return !!line && edgeMidpoints.value.some(point => Math.abs(distanceToLine(line, point)) * zoom.value < 0.001)
})
const vertexSnapped = computed(() => {
  const line = displayedLine.value
  return !!line && !!active.value?.vertices.some(point => Math.abs(distanceToLine(line, point)) * zoom.value < 0.001)
})
const cutAngle = computed(() => {
  const line = displayedLine.value
  const piece = active.value
  if (!line || !piece) return
  const match = cutAngleToEdges(sub(line.to, line.from), piece.vertices)
  if (match) return { degrees: Math.round(match.relative * 180 / Math.PI), snapped: match.error < 1e-8 }
})
const cutResult = computed(() => mode.value === 'cut' && active.value && displayedLine.value
  ? splitPolygon(active.value.vertices, displayedLine.value)
  : null)
const tutorials: Record<Mode, { label: string; tipTitle: string; tip?: string; steps: { title: string; hint: string; symbol?: string }[] }> = {
  cut: {
    label: '切割步骤', tipTitle: '切线提示',
    steps: [
      { title: '点第一个点', hint: '在画布上点一下' },
      { title: '点第二个点', hint: '两点连成切线' },
      { title: '调整并切割', hint: '拖动把手，再点确认' },
    ],
  },
  move: {
    label: '移动步骤', tipTitle: '移动提示', tip: '拖空白处可以移动画布。拖图形靠近另一块彩纸的边时会自动贴齐。',
    steps: [
      { title: '按住图形', hint: '选中要移动的彩纸', symbol: '•' },
      { title: '拖到新位置', hint: '彩纸会跟着你走', symbol: '↔' },
      { title: '贴齐再松手', hint: '看到接缝高亮就松手', symbol: '✓' },
    ],
  },
  rotate: {
    label: '旋转步骤', tipTitle: '旋转提示', tip: '图形的边接近水平或垂直时会自动对齐。拖过吸附范围即可继续转。',
    steps: [
      { title: '按住图形边', hint: '靠近边缘更好转', symbol: '•' },
      { title: '绕中心拖动', hint: '围着中心点画弧', symbol: '↻' },
      { title: '对齐再松手', hint: '边高亮时已对齐', symbol: '✓' },
    ],
  },
}
const cutStep = computed(() => cutAnimation.value ? tutorials.cut.steps.length : displayedLine.value ? 2 : firstCutPoint.value ? 1 : 0)
const cutStatus = computed(() => {
  if (!active.value) return '请先添加并选中一个图形。'
  if (!displayedLine.value) return '点靠近角或边中点时，会自动贴到那个点上。'
  return cutResult.value ? '拖圆形把手调角度，拖线中间移位置。' : '让切线穿过整块彩纸，就能剪开。'
})
const instruction = computed(() => {
  if (cutAnimation.value) return '正在剪开彩纸…'
  if (!solids.value.length) return '从「添加图形」选一张彩纸开始。'
  if (!active.value) return '点选画布上的图形进行操作。'
  return ({
    move: '拖动图形换位置，拖空白处移动整张画布。',
    rotate: rotationGuide.value?.label ?? '绕中心点拖动，靠近水平或垂直时会自动对齐。',
    cut: firstCutPoint.value !== undefined ? '已选第一个点，请点第二个点。'
      : cutLine.value ? '确认切割，或拖动把手微调。'
        : '先点一下，放下切线的第一个点。',
  })[mode.value]
})
let nextId = 1

type RecordChange = { addedId: string } | { cleared: GeometryCutRecord[] }

function state(recordChange?: RecordChange) {
  return { solids: solids.value, selected: selected.value, mode: mode.value, feedback: feedback.value, line: cutLine.value, recordChange }
}
const history = shallowRef<ReturnType<typeof state>[]>([])
function snapshot(recordChange?: RecordChange) {
  history.value = [...history.value.slice(-39), state(recordChange)]
}

function setMode(next: Mode) {
  if (mode.value !== next) cutLine.value = undefined
  mode.value = next
}

function select(id: number) {
  if (selected.value !== id) cutLine.value = undefined
  selected.value = id
}

function clearCutPoints() {
  firstCutPoint.value = undefined
  cutLine.value = undefined
  liveLine.value = undefined
}

function pickCutPoint(screenPoint: Point) {
  const nearest = snapPoints.value.reduce<{ point?: Point; distance: number }>((best, { point }) => {
    const distance = Math.hypot(...sub(project(point), screenPoint))
    return distance < best.distance ? { point, distance } : best
  }, { distance: 20 })
  const point = nearest.point ?? unproject(screenPoint)
  const first = firstCutPoint.value
  if (!first) {
    firstCutPoint.value = point
    return
  }
  if (Math.hypot(...sub(point, first)) * zoom.value < 8) return
  cutLine.value = { from: first, to: point }
  firstCutPoint.value = undefined
}

function spawn(shape: Shape, remember = true) {
  stopCutAnimation()
  if (remember) snapshot()
  const positions = solids.value.map(piece => center(piece.vertices))
  const candidates: Point[] = [[0, 0], [2, 0], [-2, 0], [0, 1.7], [0, -1.7]]
  const clearance = (point: Point) => Math.min(...positions.map(position => Math.hypot(...sub(point, position))))
  const offset = candidates.reduce((best, point) => clearance(point) > clearance(best) ? point : best)
  const id = nextId++
  const vertices = makeShape(shape).map(point => add(point, offset))
  const color = shapes.find(item => item.key === shape)!.color
  solids.value = [...solids.value, { id, vertices, color }]
  select(id)
  feedback.value = ''
  fitView()
}

function reset(remember = true) {
  if (remember) {
    snapshot({ cleared: cutRecords.value })
    updateCutRecords([])
  }
  solids.value = []
  mode.value = 'cut'
  clearCutPoints()
  spawn('square', false)
}

function undo() {
  const previous = history.value.at(-1)
  if (!previous) return
  stopCutAnimation()
  history.value = history.value.slice(0, -1)
  solids.value = previous.solids
  selected.value = previous.selected
  mode.value = previous.mode
  feedback.value = previous.feedback
  cutLine.value = previous.line
  const change = previous.recordChange
  if (change) {
    updateCutRecords('cleared' in change ? change.cleared : cutRecords.value.filter(record => record.id !== change.addedId))
  }
  if (!allInView()) fitView()
}

function deleteSelected() {
  const piece = active.value
  if (!piece) return
  stopCutAnimation()
  snapshot()
  solids.value = solids.value.filter(item => item.id !== piece.id)
  selected.value = undefined
  cutLine.value = undefined
  feedback.value = '已删除选中图形'
}

function transformPiece(piece: Piece, transform: (point: Point) => Point): Piece {
  return { ...piece, vertices: piece.vertices.map(transform) }
}

function stopCutAnimation() {
  if (cutAnimationFrame !== undefined) cancelAnimationFrame(cutAnimationFrame)
  cutAnimationFrame = undefined
  cutAnimation.value = undefined
}

function playCutAnimation(animation: Omit<CutAnimation, 'elapsed'>) {
  stopCutAnimation()
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
  const start = performance.now()
  const duration = cutStrokeDuration + cutSeparationDuration
  cutAnimation.value = { ...animation, elapsed: 0 }
  function tick(now: number) {
    const elapsed = Math.max(0, now - start)
    if (elapsed >= duration) {
      stopCutAnimation()
      return
    }
    cutAnimation.value = { ...animation, elapsed }
    cutAnimationFrame = requestAnimationFrame(tick)
  }
  cutAnimationFrame = requestAnimationFrame(tick)
}

function cut() {
  const piece = active.value
  const result = cutResult.value
  const line = displayedLine.value
  if (!piece || !result || !line) return
  const recordId = randomUuid()
  snapshot({ addedId: recordId })
  const previous = solids.value
  const [dx, dy] = sub(line.to, line.from)
  const normal = scale([-dy, dx], 0.3 / Math.hypot(dx, dy))
  const separate = (vertices: Point[], direction: number) => {
    const delta = scale(normal, direction)
    return transformPiece({ ...piece, id: nextId++, vertices }, point => add(point, delta))
  }
  const first = separate(result.positive, 1)
  const second = separate(result.negative, -1)
  solids.value = [...solids.value.filter(item => item.id !== piece.id), first, second]
  select(first.id)
  feedback.value = `切开啦！一个${geometryShapeName(first.vertices)}和一个${geometryShapeName(second.vertices)}`
  if (!allInView()) fitView()
  const [edgeX, edgeY] = sub(result.edge.to, result.edge.from)
  const edge = edgeX * dx + edgeY * dy < 0 ? { from: result.edge.to, to: result.edge.from } : result.edge
  updateCutRecords([{
    id: recordId, timestamp: Date.now(), color: piece.color, before: piece.vertices,
    pieces: [result.positive, result.negative], edge,
  }, ...cutRecords.value])
  playCutAnimation({
    previous, originalId: piece.id, firstId: first.id, secondId: second.id, offset: normal, edge,
  })
}

const screenCenter = computed<Point>(() => [viewport.value.width / 2, viewport.value.height / 2])
const project = (point: Point) => add(screenCenter.value, scale(sub(point, camera.value), zoom.value))
const unproject = (point: Point) => add(camera.value, scale(sub(point, screenCenter.value), 1 / zoom.value))

function fitView() {
  const points = solids.value.flatMap(piece => piece.vertices)
  if (!points.length) return
  const xs = points.map(point => point[0])
  const ys = points.map(point => point[1])
  const left = Math.min(...xs)
  const top = Math.min(...ys)
  const width = Math.max(...xs) - left
  const height = Math.max(...ys) - top
  camera.value = [left + width / 2, top + height / 2]
  zoomFactor.value = baseZoom.value
    ? Math.min(1.4, viewport.value.width * 0.77 / (width * baseZoom.value), viewport.value.height * 0.74 / (height * baseZoom.value))
    : 1
}

function changeZoom(direction: number) {
  zoomFactor.value = Math.max(0.08, Math.min(3, zoomFactor.value * 1.22 ** direction))
}

function allInView() {
  return solids.value.every(piece => piece.vertices.every(point => {
    const [x, y] = project(point)
    return x > 20 && y > 20 && x < viewport.value.width - 20 && y < viewport.value.height - 20
  }))
}

function paint(ctx: CanvasRenderingContext2D) {
  const { width, height } = viewport.value
  ctx.clearRect(0, 0, width, height)
  const stroke = (line: Line, color: string, width: number) => {
    ctx.beginPath()
    ctx.moveTo(...project(line.from))
    ctx.lineTo(...project(line.to))
    ctx.strokeStyle = color
    ctx.lineWidth = width
    ctx.stroke()
  }
  const animation = cutAnimation.value
  const tracing = animation && animation.elapsed < cutStrokeDuration
  const separation = animation ? Math.max(0, (animation.elapsed - cutStrokeDuration) / cutSeparationDuration) : 1
  const overshoot = 1.35
  const progress = separation - 1
  const remaining = -(overshoot + 1) * progress ** 3 - overshoot * progress ** 2
  for (const piece of tracing ? animation.previous : solids.value) {
    const side = piece.id === animation?.firstId ? 1 : piece.id === animation?.secondId ? -1 : 0
    const offset = animation && side ? scale(animation.offset, -side * remaining) : null
    ctx.beginPath()
    piece.vertices.forEach((point, i) => {
      const position = project(offset ? add(point, offset) : point)
      if (i) ctx.lineTo(...position)
      else ctx.moveTo(...position)
    })
    ctx.closePath()
    ctx.fillStyle = piece.color
    ctx.strokeStyle = piece.id === (tracing ? animation.originalId : selected.value) ? '#29344d' : '#67738a'
    ctx.lineWidth = 1.5
    ctx.fill()
    ctx.stroke()
  }
  if (tracing) {
    const { edge, elapsed } = animation
    const tip = add(edge.from, scale(sub(edge.to, edge.from), elapsed / cutStrokeDuration))
    ctx.save()
    ctx.lineCap = 'round'
    stroke({ from: edge.from, to: tip }, '#f5c851', 7)
    stroke({ from: edge.from, to: tip }, '#fff5c6', 2)
    ctx.beginPath()
    ctx.arc(...project(tip), 5, 0, Math.PI * 2)
    ctx.fillStyle = '#fff'
    ctx.fill()
    ctx.strokeStyle = '#b66c16'
    ctx.lineWidth = 2
    ctx.stroke()
    ctx.restore()
  } else if (animation) {
    paintCutConfetti(ctx, animation.edge, separation)
  }
  if (animation) return
  if (mode.value === 'move' && moveSeam.value) stroke(moveSeam.value, '#087d6e', 3)
  if (mode.value === 'rotate' && active.value) {
    if (rotationGuide.value) stroke(rotationGuide.value.edge, '#6b39a1', 3)
    ctx.beginPath()
    ctx.arc(...project(polygonCentroid(active.value.vertices)), 4, 0, 2 * Math.PI)
    ctx.fillStyle = '#fff'
    ctx.fill()
    ctx.strokeStyle = '#624080'
    ctx.lineWidth = 2
    ctx.stroke()
  }
  const line = displayedLine.value
  if (mode.value !== 'cut') return
  if (line) paintCutLine(ctx, line, stroke)
  if (!active.value) return
  for (const { point, vertex } of snapPoints.value) {
    const aligned = line && Math.abs(distanceToLine(line, point)) * zoom.value < 0.5
    ctx.beginPath()
    ctx.arc(...project(point), vertex && !aligned ? 4 : 5.5, 0, 2 * Math.PI)
    ctx.fillStyle = aligned ? '#086e70' : '#526078'
    ctx.strokeStyle = '#fff'
    ctx.lineWidth = 1.5
    ctx.fill()
    ctx.stroke()
  }
  if (line && cutLine.value) {
    paintPointNumber(ctx, line.from, '1', '#5141b8')
    paintPointNumber(ctx, line.to, '2', '#086e70')
  } else if (firstCutPoint.value) {
    paintPointNumber(ctx, firstCutPoint.value, '1', '#5141b8')
  }
}

function paintPointNumber(ctx: CanvasRenderingContext2D, point: Point, label: string, color: string) {
  const [x, y] = project(point)
  ctx.save()
  ctx.beginPath()
  ctx.arc(x, y, 10, 0, 2 * Math.PI)
  ctx.fillStyle = color
  ctx.fill()
  ctx.strokeStyle = '#fff'
  ctx.lineWidth = 2
  ctx.stroke()
  ctx.fillStyle = '#fff'
  ctx.font = 'bold 11px sans-serif'
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  ctx.fillText(label, x, y)
  ctx.restore()
}

function paintCutConfetti(ctx: CanvasRenderingContext2D, edge: Line, progress: number) {
  const direction = sub(edge.to, edge.from)
  const drift = 1 - (1 - progress) ** 2
  ctx.save()
  ctx.globalAlpha = Math.min(1, (1 - progress) * 2.4)
  for (let i = 0; i < 12; i++) {
    const origin = project(add(edge.from, scale(direction, 0.2 + 0.3 * (i % 3))))
    const angle = i * 2.4
    const reach = 32 + (i % 4) * 9
    const point = add(origin, [Math.cos(angle) * reach * drift, Math.sin(angle) * reach * drift + 24 * progress ** 2])
    ctx.save()
    ctx.translate(...point)
    ctx.rotate(angle + progress * 3)
    ctx.fillStyle = confettiColors[i % confettiColors.length]!
    if (i % 3 === 0) {
      ctx.beginPath()
      for (let pointIndex = 0; pointIndex < 10; pointIndex++) {
        const theta = pointIndex * Math.PI / 5 - Math.PI / 2
        const radius = pointIndex % 2 === 0 ? 8 : 3.5
        const vertex: Point = [Math.cos(theta) * radius, Math.sin(theta) * radius]
        if (pointIndex === 0) ctx.moveTo(...vertex)
        else ctx.lineTo(...vertex)
      }
      ctx.closePath()
      ctx.fill()
    } else {
      ctx.fillRect(-2.5, -4, 5, 8)
    }
    ctx.restore()
  }
  ctx.restore()
}

function paintCutLine(ctx: CanvasRenderingContext2D, line: Line, stroke: (line: Line, color: string, width: number) => void) {
  const result = cutResult.value
  const color = result ? '#086e70' : '#ad472c'
  if (result) {
    ctx.beginPath()
    result.positive.forEach((point, i) => i ? ctx.lineTo(...project(point)) : ctx.moveTo(...project(point)))
    ctx.closePath()
    ctx.fillStyle = '#ffffff54'
    ctx.fill()
  }
  ctx.setLineDash([6, 5])
  stroke(line, color, 2)
  ctx.setLineDash([])
  if (result) stroke(result.edge, color, 2)
  if (cutLine.value) {
    ctx.beginPath()
    ctx.arc(...project(scale(add(line.from, line.to), 0.5)), 7, 0, 2 * Math.PI)
    ctx.fillStyle = '#fff'
    ctx.fill()
    ctx.strokeStyle = color
    ctx.lineWidth = 2
    ctx.stroke()
  }
}

let observer: ResizeObserver | undefined
onMounted(() => {
  observer = new ResizeObserver(([entry]) => {
    if (!entry) return
    const { width, height } = entry.contentRect
    viewport.value = { width, height }
  })
  if (canvas.value) observer.observe(canvas.value)
})
onBeforeUnmount(() => {
  observer?.disconnect()
  stopCutAnimation()
})

watchEffect(() => {
  const element = canvas.value
  const { width, height } = viewport.value
  if (!element || !width || !height) return
  const ratio = Math.min(window.devicePixelRatio || 1, 2)
  const pixelWidth = Math.round(width * ratio)
  const pixelHeight = Math.round(height * ratio)
  if (element.width !== pixelWidth || element.height !== pixelHeight) {
    element.width = pixelWidth
    element.height = pixelHeight
  }
  const ctx = element.getContext('2d')
  if (!ctx) return
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0)
  paint(ctx)
})

type CutHandle = 'from' | 'to' | 'move'
type RotationDrag = { pivot: Point; deadZone: number; lastAngle?: number; angle: number }
let gesture: {
  pointer: number; from: Point; last: Point; saved: boolean; hit?: number
  originalVertices?: Point[]
  panOrigin?: Point
  adjustment?: { line: Line; handle: CutHandle }
  rotation?: RotationDrag
} | undefined
function pointerPoint(event: PointerEvent): Point {
  const rect = canvas.value!.getBoundingClientRect()
  return [event.clientX - rect.left, event.clientY - rect.top]
}

function hitShape(point: Point) {
  return [...solids.value].reverse().find(piece => polygonEdges(piece.vertices).every(({ from, to }) =>
    cross(sub(to, from), sub(point, from)) >= -1e-7))?.id
}

function hitCutHandle(line: Line, point: Point): CutHandle | undefined {
  const from = project(line.from)
  const to = project(line.to)
  const fromDistance = Math.hypot(...sub(point, from))
  const toDistance = Math.hypot(...sub(point, to))
  if (Math.min(fromDistance, toDistance) <= 21) return fromDistance <= toDistance ? 'from' : 'to'
  const [dx, dy] = sub(to, from)
  const [x, y] = sub(point, from)
  const t = (x * dx + y * dy) / (dx * dx + dy * dy)
  if (t >= 0 && t <= 1 && Math.hypot(x - t * dx, y - t * dy) <= 16) return 'move'
}

function startDrag(event: PointerEvent) {
  if (event.button !== 0 || gesture || !zoom.value) return
  stopCutAnimation()
  const from = pointerPoint(event)
  const hit = hitShape(unproject(from))
  const panOrigin = mode.value === 'move' && hit === undefined ? camera.value : undefined
  if (!panOrigin && (mode.value !== 'cut' || !active.value)) {
    if (hit === undefined) return
    select(hit)
  }
  const line = mode.value === 'cut' ? cutLine.value : undefined
  const handle = line && hitCutHandle(line, from)
  const vertices = mode.value === 'cut' || panOrigin ? undefined : active.value?.vertices
  let rotation: RotationDrag | undefined
  if (mode.value === 'rotate' && vertices) {
    const pivot = polygonCentroid(vertices)
    const radius = Math.max(...vertices.map(point => Math.hypot(...sub(point, pivot)))) * zoom.value
    const deadZone = Math.min(12, radius * 0.2)
    rotation = { pivot, deadZone, angle: 0 }
    rotation.lastAngle = pointerAngle(from, rotation)
  }
  gesture = { pointer: event.pointerId, from, last: from, saved: false, hit, panOrigin,
    originalVertices: vertices, adjustment: line && handle ? { line, handle } : undefined, rotation }
  canvas.value!.setPointerCapture(event.pointerId)
}

function pointerAngle(point: Point, { pivot, deadZone }: RotationDrag) {
  const [x, y] = sub(point, project(pivot))
  if (Math.hypot(x, y) >= deadZone) return Math.atan2(y, x)
}

function proposedCutLine(current: NonNullable<typeof gesture>, to: Point) {
  const { adjustment } = current
  if (!adjustment) return
  const delta = scale(sub(to, current.from), 1 / zoom.value)
  const { line, handle } = adjustment
  if (handle === 'move') return { from: add(line.from, delta), to: add(line.to, delta) }
  const anchor = handle === 'from' ? line.to : line.from
  const tip = add(line[handle], delta)
  const minLength = Math.min(48, Math.hypot(...sub(line.to, line.from)) * zoom.value)
  const nearest = snapPoints.value.reduce<{ point?: Point; distance: number }>((best, { point }) => {
    const distance = Math.hypot(...sub(point, tip)) * zoom.value
    return distance < best.distance && Math.hypot(...sub(point, anchor)) * zoom.value >= minLength
      ? { point, distance } : best
  }, { distance: 16 })
  if (nearest.point) return { ...line, [handle]: nearest.point }
  const direction = sub(tip, anchor)
  if (Math.hypot(...direction) * zoom.value < minLength) return liveLine.value
  return { ...line, [handle]: add(anchor, snapCutDirection(direction, active.value?.vertices ?? [])) }
}

function updateCutGesture(current: NonNullable<typeof gesture>, to: Point) {
  const handle = current.adjustment?.handle
  const line = proposedCutLine(current, to)
  if (!line || !handle) return
  const tolerance = 10 / zoom.value
  const snap = (point: Point) => handle === 'move'
    ? snapCutLineToPoint(line, point, tolerance)
    : snapCutEndpointToPoint(line, handle, point, tolerance)
  const nearest = snapPoints.value.reduce<{ line?: Line; distance: number }>((best, { point }) => {
    const distance = Math.abs(distanceToLine(line, point))
    if (distance >= best.distance) return best
    const snapped = snap(point)
    return snapped ? { line: snapped, distance } : best
  }, { distance: tolerance })
  const center = cutCenter.value
  return nearest.line ?? (center && snap(center)) ?? line
}

function drag(event: PointerEvent) {
  if (!gesture || gesture.pointer !== event.pointerId) return
  const to = pointerPoint(event)
  if (gesture.panOrigin) {
    camera.value = sub(gesture.panOrigin, scale(sub(to, gesture.from), 1 / zoom.value))
    return
  }
  const piece = active.value
  if (!piece) return
  if (mode.value === 'cut') {
    if (Math.hypot(...sub(to, gesture.from)) >= 8) gesture.saved = true
    if (gesture.saved && gesture.adjustment) liveLine.value = updateCutGesture(gesture, to)
    return
  }
  if (!gesture.originalVertices || (to[0] === gesture.last[0] && to[1] === gesture.last[1])) return
  gesture.last = to
  const rotation = gesture.rotation
  if (rotation) {
    const last = rotation.lastAngle
    const current = pointerAngle(to, rotation)
    rotation.lastAngle = current
    if (current === undefined || last === undefined || current === last) return
    const delta = current - last
    rotation.angle += Math.atan2(Math.sin(delta), Math.cos(delta))
  }
  if (!gesture.saved) {
    snapshot()
    gesture.saved = true
  }
  if (!rotation) {
    const delta = scale(sub(to, gesture.from), 1 / zoom.value)
    const vertices = gesture.originalVertices.map(point => add(point, delta))
    const neighbors = solids.value.filter(item => item.id !== piece.id).map(item => item.vertices)
    const snap = findEdgeSnap(vertices, neighbors, 12 / zoom.value)
    moveSeam.value = snap?.seam
    solids.value = solids.value.map(item => item.id === piece.id
      ? { ...piece, vertices: snap ? vertices.map(point => add(point, snap.offset)) : vertices }
      : item)
    return
  }
  const { pivot } = rotation
  const snap = snapRotationToAxes(gesture.originalVertices, rotation.angle)
  const angle = snap?.angle ?? rotation.angle
  const cos = Math.cos(angle)
  const sin = Math.sin(angle)
  const vertices = gesture.originalVertices.map(point => {
    const [x, y] = sub(point, pivot)
    return add(pivot, [x * cos - y * sin, x * sin + y * cos])
  })
  rotationGuide.value = snap ? {
    edge: { from: vertices[snap.edgeIndex]!, to: vertices[(snap.edgeIndex + 1) % vertices.length]! },
    label: snap.axis === 'horizontal' ? '已对齐水平线' : '已对齐垂直线',
  } : undefined
  solids.value = solids.value.map(item => item.id === piece.id ? { ...piece, vertices } : item)
}

function finishDrag(event: PointerEvent) {
  if (gesture?.pointer !== event.pointerId) return
  if (mode.value === 'cut') {
    const to = pointerPoint(event)
    const moved = Math.hypot(...sub(to, gesture.from)) >= 8 || gesture.saved
    if (moved && gesture.adjustment) {
      const line = updateCutGesture(gesture, to)
      if (line) cutLine.value = line
    } else if (!moved && !firstCutPoint.value && gesture.hit !== undefined && gesture.hit !== selected.value) {
      select(gesture.hit)
    } else if (!moved && active.value && !cutLine.value) {
      pickCutPoint(to)
    }
  } else if (gesture.rotation || gesture.panOrigin) {
    drag(event)
  }
  cancelDrag(event)
}

function cancelDrag(event: PointerEvent) {
  if (gesture?.pointer !== event.pointerId) return
  gesture = undefined
  liveLine.value = undefined
  moveSeam.value = undefined
  rotationGuide.value = undefined
}

reset(false)
</script>

<style scoped>
.geometry-page {
  --ink: #243355;
  --muted: #4e5f7c;
  --blue: #294ba6;
  --line: #dbe4f4;
  width: 100%;
  max-width: 1540px;
  margin-inline: auto;
  padding: clamp(16px, 3vw, 40px) clamp(12px, 3vw, 40px) calc(100px + env(safe-area-inset-bottom));
  color: var(--ink);
}
.game-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 16px;
  padding: clamp(14px, 2vw, 24px);
  border: 1px solid #cbdcf7;
  border-radius: 22px;
  background: #eaf3ff;
}
.game-title { display: flex; align-items: center; gap: 14px; min-width: 0; }
.logo {
  display: grid;
  flex: none;
  place-items: center;
  width: 52px;
  height: 52px;
  border: 1px solid #cadbf4;
  border-radius: 16px;
  background: white;
  color: var(--blue);
  font-size: 1.65rem;
}
h1, h2, p { margin: 0; }
h1 { font-size: clamp(1.55rem, 3.4vw, 2.4rem); line-height: 1.2; }
.game-title p { margin-top: 5px; color: var(--muted); font-size: .88rem; }
.paper-art { display: flex; align-items: center; gap: 12px; padding: 2px 8px 2px 0; }
.paper-art i { display: block; width: 30px; height: 30px; background: #f6c853; transform: rotate(-14deg); }
.paper-art i:nth-child(2) { width: 42px; height: 25px; background: #79cdb9; transform: rotate(12deg); }
.paper-art i:nth-child(3) { width: 33px; height: 30px; background: #ec98b8; transform: rotate(-9deg); clip-path: polygon(50% 0, 100% 100%, 0 100%); }
.game-layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(216px, 250px);
  grid-template-rows: auto auto 1fr;
  gap: 12px;
  align-items: start;
}
.workspace, .panel { min-width: 0; background: #fff; border: 1px solid var(--line); border-radius: 18px; }
.workspace { grid-column: 1; grid-row: 1 / span 3; overflow: hidden; }
.palette, .cut-panel, .board-actions { grid-column: 2; }
.palette { grid-row: 1; }
.board-actions { grid-row: 2; }
.cut-panel { grid-row: 3; }
.cut-records { grid-column: 1 / -1; }
.records-header { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.records-header span, .records-message { color: var(--muted); font-size: .84rem; }
.record-list { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 235px), 1fr)); gap: 10px; margin: 0; padding: 0; list-style: none; }
.record-list li { min-width: 0; padding: 8px; border: 1px solid var(--line); border-radius: 12px; }
.record-caption { display: grid; grid-template-columns: 1fr 1fr; text-align: center; margin-top: 4px; color: var(--muted); font-size: .72rem; }
.record-details { display: grid; gap: 3px; margin: 8px 3px 2px; font-size: .82rem; }
.record-details time { color: var(--muted); font-size: .72rem; }
.cut-records > button { justify-self: start; }
.panel { display: grid; gap: 10px; padding: 14px; }
h2 { font-size: 1rem; font-weight: 750; }
button {
  min-width: 44px;
  min-height: 44px;
  padding: 8px 12px;
  border: 1px solid var(--line);
  border-radius: 11px;
  background: #fff;
  color: inherit;
  font: inherit;
  font-weight: 650;
  font-size: .88rem;
  cursor: pointer;
}
button:hover:not(:disabled) { border-color: #899fcb; }
button:focus-visible { outline: 2px solid var(--blue); outline-offset: 2px; }
button:disabled { color: #65738b; background: #f1f4f9; border-color: #dce3f0; cursor: default; }
.workspace-header { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 8px; padding: 10px 12px; }
.tool-group, .view-tools { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; }
.tool { display: inline-flex; align-items: center; justify-content: center; gap: 6px; }
.tool span { font-size: 1.08rem; }
.tool[aria-pressed="true"] { color: #203f94; background: #e5eeff; border-color: #9eb7eb; }
.tool[data-tool="move"][aria-pressed="true"] { color: #215d50; background: #e3f7ef; border-color: #a2d7c5; }
.tool[data-tool="rotate"][aria-pressed="true"] { color: #624080; background: #f3eaff; border-color: #d6bce9; }
.view-tools button { padding-inline: 9px; font-size: .8rem; font-weight: 600; }
.cut-steps {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  margin: 0;
  padding: 0 12px 9px;
  gap: 5px;
  list-style: none;
}
.cut-steps li { display: flex; align-items: center; gap: 8px; min-height: 52px; padding: 6px; border: 1px solid #e5ebf5; border-radius: 10px; color: var(--muted); background: #f5f7fb; }
.cut-steps li[aria-current="step"] { background: #fff1ca; border-color: #ead38e; color: #653d11; }
.cut-steps li.done { background: #eaf7ef; border-color: #cfe8dc; color: #24604d; }
.step-copy { display: grid; gap: 2px; font-size: .76rem; line-height: 1.35; }
.step-copy span { font-size: .7rem; }
.step-picture { position: relative; flex: none; width: 58px; height: 38px; }
.step-paper { position: absolute; inset: 7px 9px; background: #f6c853; border: 1px solid #a96a19; border-radius: 2px; }
.step-line { position: absolute; inset: 18px 9px auto; border-top: 2px dashed #086e70; }
.step-dot { position: absolute; top: 12px; left: 3px; display: grid; place-items: center; width: 14px; height: 14px; border-radius: 50%; background: #5141b8; color: #fff; font: 700 9px/1 sans-serif; }
.step-dot.second { left: auto; right: 3px; background: #086e70; }
.cut-steps[data-tool="cut"] .step-picture[data-step="2"] .step-paper { inset: 5px 9px 21px; transform: rotate(-5deg); }
.cut-steps[data-tool="cut"] .step-picture[data-step="2"] .step-paper.second { inset: 22px 9px 4px; transform: rotate(5deg); }
.step-scissors { position: absolute; inset: 10px 0 auto auto; color: #5141b8; font-size: .9rem; font-style: normal; }
.cut-steps[data-tool="move"] li { background: #eaf7ef; border-color: #cfe8dc; color: #215d50; }
.cut-steps[data-tool="move"] .step-paper { background: #79cdb9; border-color: #3d8b77; inset: 8px 18px 8px 8px; }
.cut-steps[data-tool="move"] [data-step="2"] .step-paper { inset: 8px 29px 8px 8px; }
.cut-steps[data-tool="move"] [data-step="2"] .step-paper.second { inset: 8px 8px 8px 29px; }
.cut-steps[data-tool="rotate"] li { background: #f3eaff; border-color: #e1cfee; color: #624080; }
.cut-steps[data-tool="rotate"] .step-paper { inset: 7px 17px; background: #c2a2e1; border-color: #865aab; }
.cut-steps[data-tool="rotate"] [data-step="1"] .step-paper { transform: rotate(28deg); }
.step-pivot { position: absolute; inset: 16px auto auto 26px; width: 6px; height: 6px; border-radius: 50%; background: #fff; border: 1px solid #865aab; }
.step-symbol { position: absolute; inset: 8px 2px auto auto; display: grid; place-items: center; width: 18px; height: 18px; border-radius: 50%; background: #fff; color: inherit; font: 700 13px/1 sans-serif; }
.stage {
  position: relative;
  border-block: 1px solid var(--line);
  background-color: #fcfdff;
  background-image: linear-gradient(#e9eef8 1px, transparent 1px), linear-gradient(90deg, #e9eef8 1px, transparent 1px);
  background-position: calc(50% + var(--grid-x, 0px)) calc(50% + var(--grid-y, 0px));
  background-size: 24px 24px;
}
.work-canvas { display: block; width: 100%; height: clamp(330px, 50dvh, 660px); touch-action: none; cursor: grab; }
.work-canvas:active { cursor: grabbing; }
.stage[data-mode="cut"] .work-canvas { cursor: crosshair; }
.stage-empty { position: absolute; inset: 50% 12px auto; transform: translateY(-50%); text-align: center; color: var(--muted); pointer-events: none; }
.view-note { position: absolute; left: 12px; bottom: 10px; pointer-events: none; padding: 3px 8px; border: 1px solid var(--line); border-radius: 99px; background: white; font-size: .75rem; color: var(--muted); }
.workspace-footer { min-height: 68px; display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 8px 14px; padding: 10px 12px; }
.workspace-message { display: grid; flex: 1 1 205px; gap: 3px; color: var(--muted); font-size: .85rem; }
.feedback { color: #17644f; font-size: .95rem; }
.cut-button { min-width: 128px; background: var(--blue); border-color: var(--blue); color: white; font-weight: 750; }
.cut-button span { font-size: 1.1rem; }
.reserved-cut-button { visibility: hidden; }
.shape-list { display: grid; gap: 7px; }
.shape-list button { display: flex; align-items: center; text-align: left; gap: 8px; padding: 9px 10px; background: var(--paper-light); }
.shape-icon { width: 22px; height: 22px; flex: none; background: var(--paper); }
.shape-icon.rectangle { width: 26px; height: 16px; }
.shape-icon.triangle { clip-path: polygon(50% 0, 100% 100%, 0 100%); }
.add-shape { margin-inline-start: auto; color: var(--muted); }
.cut-panel p { color: var(--muted); font-size: .84rem; line-height: 1.55; }
.snap-list { display: flex; flex-wrap: wrap; gap: 4px; }
.snap-list span { padding: 3px 6px; border-radius: 6px; background: #eaf1ff; color: #274796; font-size: .72rem; font-variant-numeric: tabular-nums; }
.quiet-button { background: #f5f7fb; }
.delete-button:not(:disabled) { color: #962d49; }
@media (max-width: 820px) {
  .paper-art { display: none; }
  .game-layout { grid-template-columns: minmax(0, 1fr); grid-template-rows: auto; }
  .workspace, .palette, .cut-panel, .board-actions { grid-column: 1; grid-row: auto; }
  .palette { order: -1; }
  .palette { gap: 6px; padding: 10px; }
  .shape-list { grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 4px; }
  .shape-list button { justify-content: center; gap: 4px; padding-inline: 4px; font-size: .78rem; }
  .shape-icon { width: 17px; height: 17px; }
  .shape-icon.rectangle { width: 20px; height: 12px; }
  .add-shape { display: none; }
  .work-canvas { height: clamp(248px, 42dvh, 450px); }
}
@media (max-width: 420px) {
  .logo { width: 42px; height: 42px; }
  .workspace-header, .workspace-footer { padding-inline: 8px; }
  .cut-steps { padding-inline: 8px; }
  .cut-steps li { flex-direction: column; justify-content: center; gap: 2px; padding: 4px 2px; text-align: center; }
  .step-copy { font-size: .68rem; }
  .step-copy span { display: none; }
  .tool { padding-inline: 8px; }
  .view-tools { gap: 3px; }
  .view-tools button { padding-inline: 6px; }
  .cut-button { width: 100%; }
}
</style>
