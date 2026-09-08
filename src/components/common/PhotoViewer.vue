<template>
  <dialog ref="dialog" class="photo-viewer" aria-label="照片全屏预览" @close="reset">
    <header class="viewer-toolbar">
      <span>照片预览</span>
      <div>
        <button aria-label="缩小照片" :disabled="scale <= 1" @click="zoom(-0.5)">−</button>
        <output aria-live="polite">{{ Math.round(scale * 100) }}%</output>
        <button aria-label="放大照片" :disabled="scale >= 5" @click="zoom(0.5)">＋</button>
        <button @click="reset">适应屏幕</button>
        <button autofocus @click="dialog?.close()">关闭大图</button>
      </div>
    </header>
    <div class="viewer-stage" :class="{ zoomed: scale > 1 }" @wheel.prevent="zoom($event.deltaY < 0 ? 0.25 : -0.25)"
      @pointerdown="start" @pointermove="move" @pointerup="end" @pointercancel="end" @lostpointercapture="end" @dblclick="scale > 1 ? reset() : zoom(1)">
      <img v-if="source && !failed" :src="source" alt="打卡照片全屏预览" draggable="false" :style="{ transform: `translate(${x}px, ${y}px) scale(${scale})` }" @error="failed = true" />
      <p v-if="failed" role="alert">照片链接可能已过期，请关闭大图和详情，刷新记录后重试。</p>
    </div>
    <footer>点击 ＋ 放大 · 放大后拖动查看 · 支持滚轮缩放、双指缩放和双击</footer>
  </dialog>
</template>

<script setup lang="ts">
import { nextTick, ref } from 'vue'
const dialog = ref<HTMLDialogElement>()
const source = ref(''), failed = ref(false), scale = ref(1), x = ref(0), y = ref(0)
const pointers = new Map<number, { x: number; y: number }>()
function reset() { scale.value = 1; x.value = 0; y.value = 0; pointers.clear() }
function zoom(delta: number) {
  scale.value = Math.min(5, Math.max(1, scale.value + delta))
  if (scale.value === 1) { x.value = 0; y.value = 0 }
}
function start(event: PointerEvent) {
  if (event.pointerType === 'mouse' && event.button !== 0) return
  pointers.set(event.pointerId, { x: event.clientX, y: event.clientY })
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}
function distance() {
  const [a, b] = [...pointers.values()]
  return a && b ? Math.hypot(a.x - b.x, a.y - b.y) : 0
}
function move(event: PointerEvent) {
  const previous = pointers.get(event.pointerId)
  if (!previous) return
  const before = distance()
  pointers.set(event.pointerId, { x: event.clientX, y: event.clientY })
  if (pointers.size === 2 && before > 0) zoom(scale.value * (distance() / before - 1))
  else if (pointers.size === 1 && scale.value > 1) {
    x.value += event.clientX - previous.x; y.value += event.clientY - previous.y
  }
}
function end(event: PointerEvent) { pointers.delete(event.pointerId) }
async function open(url: string) {
  source.value = url; failed.value = false; reset()
  await nextTick(); dialog.value?.showModal()
}
defineExpose({ open })
</script>

<style scoped>
.photo-viewer { position:fixed; inset:0; width:100vw; height:100dvh; max-width:none; max-height:none; margin:0; padding:0; border:0; background:#17191d; color:white; overflow:hidden; }
.photo-viewer[open] { display:flex; flex-direction:column; }.photo-viewer::backdrop { background:#17191d; }
.viewer-toolbar { display:flex; align-items:center; justify-content:space-between; gap:12px; padding:12px max(16px,env(safe-area-inset-right)) 12px max(16px,env(safe-area-inset-left)); background:#252830; z-index:1; }
.viewer-toolbar div { display:flex; align-items:center; flex-wrap:wrap; gap:8px; }.viewer-toolbar button { border:1px solid #67707d; color:white; background:#343943; border-radius:8px; padding:8px 12px; min-height:44px; cursor:pointer; }.viewer-toolbar button:disabled { opacity:.4; cursor:default; }.viewer-toolbar button:focus-visible { outline:3px solid #ff9ccd; outline-offset:2px; }.viewer-toolbar output { width:50px; text-align:center; font-size:.85rem; }
.viewer-stage { flex:1; min-height:0; overflow:hidden; display:flex; align-items:center; justify-content:center; touch-action:none; user-select:none; }.viewer-stage.zoomed { cursor:grab; }.viewer-stage.zoomed:active { cursor:grabbing; }.viewer-stage img { width:100%; height:100%; object-fit:contain; pointer-events:none; flex-shrink:0; }.viewer-stage p { padding:24px; text-align:center; }
footer { padding:10px 16px max(10px,env(safe-area-inset-bottom)); text-align:center; color:#c4c8d0; font-size:.8rem; z-index:1; background:#252830; }
@media(max-width:600px) { .viewer-toolbar { flex-direction:column; align-items:flex-start; gap:6px; }.viewer-toolbar div { width:100%; justify-content:space-between; gap:4px; }.viewer-toolbar button { padding:8px; }.viewer-toolbar > span { font-size:.85rem; } }
</style>
