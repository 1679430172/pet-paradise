<template>
  <div class="picture-game">
    <h1>图片切切乐</h1>
    <p>按住滑过图片，松开后切割。长按图片块可移动图片块，长按空白处可移动画布。</p>
    <div class="shape-picker">
      <strong>切换图形</strong>
      <button v-for="option in shapes" :key="option.id" type="button"
        :aria-pressed="option.id === shape" @click="switchShape(option.id)">{{ option.label }}</button>
      <div class="history-actions">
        <button type="button" :disabled="!!snip || !undoStack.length" @click="undo">撤销</button>
        <button type="button" :disabled="!!snip || !redoStack.length" @click="redo">重做</button>
      </div>
    </div>

    <svg ref="board" class="board" viewBox="-320 -200 640 400" aria-label="图片切割画布"
      @pointerdown="startGesture" @pointermove="moveGesture" @pointerup="finishGesture"
      @pointercancel="clearGesture" @lostpointercapture="clearGesture" @contextmenu.prevent>
      <defs>
        <pattern :id="gridId" width="24" height="24" patternUnits="userSpaceOnUse"
          :patternTransform="translate(pan)">
          <path d="M 24 0 H 0 V 24" fill="none" stroke="#e2eafa" />
        </pattern>
      </defs>
      <rect x="-100%" y="-100%" width="200%" height="200%" :fill="`url(#${gridId})`" />
      <g :transform="translate(pan)">
        <g v-for="piece in pieces" :key="piece.id" :transform="translate(piece.offset)">
          <g :class="{ separating: piece.separation }" :style="separationStyle(piece.separation)">
            <PictureFragment :vertices="piece.vertices" :picture="currentShape.picture" :data-piece="piece.id" />
          </g>
        </g>
      </g>
      <line v-if="preview" :x1="preview.from[0]" :y1="preview.from[1]"
        :x2="preview.to[0]" :y2="preview.to[1]" class="blade" />
      <g v-if="snip" class="snip" aria-hidden="true">
        <line :x1="snip.start[0]" :y1="snip.start[1]"
          :x2="snip.position[0]" :y2="snip.position[1]" class="cut-trail" />
        <g :transform="`${translate(snip.position)} rotate(${snip.angle})`" class="scissors">
          <g class="scissor-blade upper">
            <path d="M -7 0 H 15 L 19 -2 L -7 -3 Z" />
            <circle cx="-11" cy="0" r="4" />
          </g>
          <g class="scissor-blade lower">
            <path d="M -7 0 H 15 L 19 2 L -7 3 Z" />
            <circle cx="-11" cy="0" r="4" />
          </g>
          <circle r="1.8" fill="#253754" />
        </g>
      </g>
    </svg>

    <section class="records">
      <h2>我的切割记录</h2>
      <p v-if="saveFailed" role="status">浏览器暂时无法保存切割记录。</p>
      <p v-if="!records.length">切开第一张图片后，记录会显示在这里。</p>
      <ol v-else>
        <li v-for="{ record, viewBox } in recordPreviews" :key="record.id">
          <svg :viewBox="viewBox" role="img" aria-label="切割前">
            <g v-for="(piece, index) in record.before" :key="index" :transform="translate(piece.offset)">
              <PictureFragment :vertices="piece.vertices" :picture="record.picture" />
            </g>
          </svg>
          <svg :viewBox="viewBox" role="img" aria-label="切割后">
            <g v-for="(piece, index) in record.after" :key="index" :transform="translate(piece.offset)">
              <PictureFragment :vertices="piece.vertices" :picture="record.picture" />
            </g>
          </svg>
          <span>切割前 · {{ record.before.length }} 块</span>
          <span>切割后 · {{ record.after.length }} 块</span>
          <time :datetime="new Date(record.timestamp).toISOString()">{{ dateFormat.format(record.timestamp) }}</time>
        </li>
      </ol>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, useId, watch } from 'vue'
import PictureFragment from '../components/common/PictureFragment.vue'
import { add, makeShape, scale, splitPolygon, sub, type Line, type Point, type Shape } from '../lib/geometryGame'
import { cutRecordLimit } from '../lib/geometryCutRecords'
import { useAuthStore } from '../stores/auth'

const shapes = [
  { id: 'square', label: '正方形', picture: '/assets/travel/stars-camp.webp' },
  { id: 'rectangle', label: '长方形', picture: '/assets/travel/scenes/forest-01.webp' },
  { id: 'triangle', label: '三角形', picture: '/assets/travel/stars-dawn.webp' },
] as const

interface Piece {
  id: number
  vertices: Point[]
  offset: Point
  separation?: Point
}

type RecordPiece = Pick<Piece, 'vertices' | 'offset'>

interface CutRecord {
  id: number
  timestamp: number
  picture: string
  before: RecordPiece[]
  after: RecordPiece[]
}

interface LegacyCutRecord extends Pick<CutRecord, 'id' | 'timestamp' | 'picture'> {
  before: Point[]
  pieces: [Point[], Point[]]
  offsets: [Point, Point]
}

interface BoardSnapshot {
  pieces: Piece[]
  pan: Point
  records: CutRecord[]
}

const auth = useAuthStore()
const gridId = `picture-grid-${useId()}`
const board = ref<SVGSVGElement>()
const shape = ref<Shape>('square')
const currentShape = computed(() => shapes.find(option => option.id === shape.value)!)
const pieces = ref<Piece[]>([])
const pan = ref<Point>([0, 0])
const preview = ref<Line>()
const snip = ref<{ start: Point; position: Point; angle: number }>()
const records = ref<CutRecord[]>([])
const recordPreviews = computed(() => records.value.map(record => ({
  record,
  viewBox: recordViewBox(record),
})))
const undoStack = ref<BoardSnapshot[]>([])
const redoStack = ref<BoardSnapshot[]>([])
const historyLimit = 40
const saveFailed = ref(false)
const recordKey = computed(() => auth.user ? `picture-cut-records:${auth.user.id}` : '')
const dateFormat = new Intl.DateTimeFormat('zh-CN', {
  month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Shanghai',
})
let nextPieceId = 0
let nextRecordId = 0
let gesture: Gesture | undefined
let snipFrame = 0

watch(recordKey, key => {
  resetBoard('square')
  saveFailed.value = false
  try {
    const saved: unknown = key ? JSON.parse(localStorage.getItem(key) ?? '[]') : []
    records.value = Array.isArray(saved) ? saved.slice(0, cutRecordLimit).map(readRecord) : []
  } catch {
    records.value = []
  }
  nextRecordId = Math.max(0, ...records.value.map(record => record.id))
}, { immediate: true })

interface Gesture {
  pointerId: number
  from: Point
  clientStart: Point
  mode: 'pending' | 'cut' | 'move'
  piece?: Piece
  origin: Point
  before: BoardSnapshot
  timer?: number
}

function translate(point: Point) {
  return `translate(${point.join(' ')})`
}

function readRecord(record: CutRecord | LegacyCutRecord): CutRecord {
  if ('after' in record) return record
  return {
    id: record.id,
    timestamp: record.timestamp,
    picture: record.picture,
    before: [{ vertices: record.before, offset: [0, 0] }],
    after: record.pieces.map((vertices, index) => ({ vertices, offset: record.offsets[index]! })),
  }
}

function recordViewBox(record: CutRecord) {
  let left = Infinity, right = -Infinity, top = Infinity, bottom = -Infinity
  for (const { vertices, offset } of [...record.before, ...record.after]) {
    for (const vertex of vertices) {
      const [x, y] = add(vertex, offset)
      left = Math.min(left, x)
      right = Math.max(right, x)
      top = Math.min(top, y)
      bottom = Math.max(bottom, y)
    }
  }
  const padding = Math.max(6, Math.max(right - left, bottom - top) * 0.05)
  return [left - padding, top - padding, right - left + 2 * padding, bottom - top + 2 * padding].join(' ')
}

function separationStyle(offset?: Point) {
  return offset && { '--start-x': `${-offset[0]}px`, '--start-y': `${-offset[1]}px` }
}

function resetBoard(nextShape: Shape) {
  clearGesture()
  cancelSnip()
  undoStack.value = []
  redoStack.value = []
  shape.value = nextShape
  pan.value = [0, 0]
  pieces.value = [{ id: ++nextPieceId, vertices: makeShape(nextShape).map(point => scale(point, 80)), offset: [0, 0] }]
}

function switchShape(nextShape: Shape) {
  resetBoard(nextShape)
  records.value = []
  persistRecords()
}

function snapshot(): BoardSnapshot {
  return { pieces: pieces.value, pan: pan.value, records: records.value }
}

function remember(before: BoardSnapshot) {
  undoStack.value = [...undoStack.value.slice(1 - historyLimit), before]
  redoStack.value = []
}

function restore(state: BoardSnapshot) {
  pieces.value = state.pieces
  pan.value = state.pan
  if (records.value !== state.records) {
    records.value = state.records
    persistRecords()
  }
}

function undo() {
  clearGesture()
  const previous = undoStack.value.pop()
  if (!previous) return
  redoStack.value.push(snapshot())
  restore(previous)
}

function redo() {
  clearGesture()
  const next = redoStack.value.pop()
  if (!next) return
  undoStack.value.push(snapshot())
  restore(next)
}

function boardPoint(event: PointerEvent): Point | undefined {
  const matrix = board.value?.getScreenCTM()
  if (!matrix) return
  const point = new DOMPoint(event.clientX, event.clientY).matrixTransform(matrix.inverse())
  return [point.x, point.y]
}

function startGesture(event: PointerEvent) {
  if (gesture || snip.value || event.button !== 0) return
  const from = boardPoint(event)
  if (!from || !board.value) return
  const pieceId = (event.target as Element).closest('[data-piece]')?.getAttribute('data-piece')
  const piece = pieces.value.find(item => item.id === Number(pieceId))
  const active: Gesture = {
    pointerId: event.pointerId, from, clientStart: [event.clientX, event.clientY],
    mode: 'pending', piece, origin: piece?.offset ?? pan.value, before: snapshot(),
  }
  gesture = active
  board.value.setPointerCapture(event.pointerId)
  active.timer = window.setTimeout(() => { active.mode = 'move' }, 350)
}

function moveGesture(event: PointerEvent) {
  const active = gesture
  if (active?.pointerId !== event.pointerId) return
  const point = boardPoint(event)
  if (!point) return
  if (active.mode === 'pending' && Math.hypot(...sub([event.clientX, event.clientY], active.clientStart)) >= 6) {
    window.clearTimeout(active.timer)
    active.mode = 'cut'
  }
  if (active.mode === 'cut') preview.value = { from: active.from, to: point }
  if (active.mode === 'move') {
    const offset = add(active.origin, sub(point, active.from))
    if (active.piece) {
      pieces.value = pieces.value.map(piece => piece.id === active.piece?.id ? { ...piece, offset } : piece)
    }
    else pan.value = offset
  }
}

function finishGesture(event: PointerEvent) {
  const active = gesture
  if (active?.pointerId !== event.pointerId) return
  moveGesture(event)
  const line = preview.value
  if (active.mode === 'move') {
    const offset = active.piece ? pieces.value.find(piece => piece.id === active.piece?.id)?.offset : pan.value
    if (offset && Math.hypot(...sub(offset, active.origin)) > 0) remember(active.before)
    active.mode = 'pending'
  }
  clearGesture()
  if (line) cut(line)
}

function clearGesture(event?: PointerEvent) {
  if (event && gesture?.pointerId !== event.pointerId) return
  const active = gesture
  gesture = undefined
  preview.value = undefined
  window.clearTimeout(active?.timer)
  if (active?.mode === 'move') restore(active.before)
  if (active && board.value?.hasPointerCapture(active.pointerId)) {
    board.value.releasePointerCapture(active.pointerId)
  }
}

function cut(line: Line) {
  const direction = sub(line.to, line.from)
  const length = Math.hypot(...direction)
  if (!length) return
  const unit = scale(direction, 1 / length)
  const normal: Point = [-unit[1], unit[0]]
  const separation: [Point, Point] = [scale(normal, 20), scale(normal, -20)]
  const before = snapshot()
  let firstCrossing = length
  let lastCrossing = 0

  const fragmentsAfterCut = pieces.value.flatMap(piece => {
    const origin = add(pan.value, piece.offset)
    const localLine = { from: sub(line.from, origin), to: sub(line.to, origin) }
    const result = splitPolygon(piece.vertices, localLine)
    if (!result) return [piece]
    const crossings = [result.edge.from, result.edge.to].map(point => {
      const relative = sub(point, localLine.from)
      return relative[0] * unit[0] + relative[1] * unit[1]
    })
    if (crossings.some(distance => distance < -1e-6 || distance > length + 1e-6)) return [piece]
    firstCrossing = Math.min(firstCrossing, ...crossings)
    lastCrossing = Math.max(lastCrossing, ...crossings)

    const fragments: [Point[], Point[]] = [result.positive, result.negative]
    return fragments.map((vertices, index) => ({
      id: ++nextPieceId, vertices, offset: add(piece.offset, separation[index]!),
      separation: separation[index],
    }))
  })

  if (fragmentsAfterCut.length === before.pieces.length) return
  const start = add(line.from, scale(unit, firstCrossing))
  const travel = scale(unit, lastCrossing - firstCrossing)
  const angle = Math.atan2(unit[1], unit[0]) * 180 / Math.PI
  playSnip(start, travel, angle, () => {
    remember(before)
    pieces.value = fragmentsAfterCut
    const record: CutRecord = {
      id: ++nextRecordId,
      timestamp: Date.now(),
      picture: currentShape.value.picture,
      before: before.pieces.map(({ vertices, offset }) => ({ vertices, offset })),
      after: fragmentsAfterCut.map(({ vertices, offset }) => ({ vertices, offset })),
    }
    records.value = [record, ...records.value].slice(0, cutRecordLimit)
    persistRecords()
  })
}

function playSnip(start: Point, travel: Point, angle: number, finish: () => void) {
  snip.value = { start, position: start, angle }
  const duration = window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 350 : 950
  const started = performance.now()
  function step(now: number) {
    const progress = Math.min(1, Math.max(0, (now - started) / duration))
    if (progress === 1) {
      cancelSnip()
      finish()
      return
    }
    snip.value = { start, position: add(start, scale(travel, progress)), angle }
    snipFrame = requestAnimationFrame(step)
  }
  snipFrame = requestAnimationFrame(step)
}

function cancelSnip() {
  cancelAnimationFrame(snipFrame)
  snip.value = undefined
}

function persistRecords() {
  try {
    if (recordKey.value) localStorage.setItem(recordKey.value, JSON.stringify(records.value))
    saveFailed.value = false
  } catch {
    saveFailed.value = true
  }
}

onBeforeUnmount(() => {
  clearGesture()
  cancelSnip()
})
</script>

<style scoped>
.picture-game { max-width: 1460px; margin: 0 auto; padding: 24px clamp(12px, 3vw, 40px) 96px; color: #253754; }
h1 { margin: 0; font-size: clamp(1.6rem, 4vw, 2.35rem); }
p { margin: 8px 0 16px; }
.shape-picker { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin: 0 0 10px; }
.shape-picker button { padding: 8px 14px; color: inherit; background: white; border: 1px solid #c3d4ed; border-radius: 9px; cursor: pointer; }
.shape-picker button[aria-pressed="true"] { background: #e8f1ff; border-color: #7598d1; }
.history-actions { display: flex; gap: 8px; margin-inline-start: auto; }
.history-actions button:disabled { opacity: .5; cursor: default; }
.board {
  display: block; width: 100%; height: clamp(300px, 58vh, 580px); touch-action: none; user-select: none; cursor: crosshair;
  border: 1px solid #c3d4ed; border-radius: 14px; background-color: #f9fbfe;
  overflow: hidden;
}
.blade { stroke: #2055a4; stroke-width: 2; stroke-dasharray: 6 4; stroke-linecap: round; pointer-events: none; }
.snip { pointer-events: none; }
.cut-trail { stroke: white; stroke-width: 2; stroke-linecap: round; }
.scissor-blade path { fill: #f4f7ff; stroke: #253754; stroke-width: 1.2; stroke-linejoin: round; }
.scissor-blade circle { fill: #fff0f5; stroke: #ba2559; stroke-width: 2.6; }
.scissor-blade.upper { animation: snip-upper 190ms ease-in-out infinite alternate; }
.scissor-blade.lower { animation: snip-lower 190ms ease-in-out infinite alternate; }
@keyframes snip-upper { from { transform: rotate(-10deg); } to { transform: rotate(-28deg); } }
@keyframes snip-lower { from { transform: rotate(10deg); } to { transform: rotate(28deg); } }
.separating { animation: separate 650ms cubic-bezier(.42, 0, .35, 1) both; }
@keyframes separate {
  from { transform: translate(var(--start-x), var(--start-y)); }
  to { transform: translate(0, 0); }
}
@media (prefers-reduced-motion: reduce) {
  .scissor-blade { animation-iteration-count: 1; }
  .separating { animation-duration: 250ms; }
}
.records { margin-top: 18px; padding: 14px; border: 1px solid #c3d4ed; border-radius: 14px; background: white; }
.records h2 { margin: 0; font-size: 1rem; }
.records ol { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 210px), 1fr)); gap: 10px; list-style: none; padding: 0; }
.records li { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 4px; padding: 8px; border: 1px solid #e2eafa; border-radius: 9px; text-align: center; font-size: .8rem; }
.records svg { width: 100%; aspect-ratio: 1.35; background: #f4f7fc; border-radius: 6px; }
.records time { grid-column: 1 / -1; }
</style>
