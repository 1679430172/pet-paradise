<template>
  <div class="date-time-picker">
    <button type="button" class="picker-trigger" :class="{ empty: !modelValue }" aria-haspopup="dialog" @click="open">
      <span>{{ modelValue ? modelValue.replace('T', ' ') : placeholder }}</span><span aria-hidden="true">▦</span>
    </button>
    <dialog ref="dialog" class="picker-dialog" :aria-label="label" @click="closeOnBackdrop">
      <header><strong>{{ label }}</strong><button type="button" aria-label="关闭时间选择" @click="dialog?.close()">×</button></header>
      <div class="month-navigation"><button type="button" aria-label="上个月" @click="moveMonth(-1)">‹</button><b>{{ year }} 年 {{ month + 1 }} 月</b><button type="button" aria-label="下个月" @click="moveMonth(1)">›</button></div>
      <div class="calendar">
        <span v-for="day in ['一','二','三','四','五','六','日']" :key="day" class="weekday">{{ day }}</span>
        <span v-for="blank in offset" :key="`blank-${blank}`"></span>
        <button v-for="day in days" :key="day" type="button" :class="{ selected: date === dayValue(day), today: today === dayValue(day) }" :aria-label="dayValue(day)" :aria-pressed="date === dayValue(day)" @click="date = dayValue(day)">{{ day }}</button>
      </div>
      <div class="shortcuts"><button type="button" @click="chooseDay(0)">今天</button><button type="button" @click="chooseDay(1)">明天</button></div>
      <div class="time-row">
        <span>时间</span>
        <div class="time-input">
          <input v-model="hour" aria-label="小时" :aria-invalid="!validHour" inputmode="numeric" autocomplete="off" maxlength="2" placeholder="时" @focus="selectInput" @blur="normalizeTime" @keydown.enter.prevent="confirm" />
          <button type="button" aria-label="选择小时" :aria-expanded="activeTime === 'hour'" :aria-controls="`${inputId}-options`" @click="toggleTime('hour')">▾</button>
        </div>
        <span>:</span>
        <div class="time-input">
          <input v-model="minute" aria-label="分钟" :aria-invalid="!validMinute" inputmode="numeric" autocomplete="off" maxlength="2" placeholder="分" @focus="selectInput" @blur="normalizeTime" @keydown.enter.prevent="confirm" />
          <button type="button" aria-label="选择分钟" :aria-expanded="activeTime === 'minute'" :aria-controls="`${inputId}-options`" @click="toggleTime('minute')">▾</button>
        </div>
      </div>
      <div v-if="activeTime" :id="`${inputId}-options`" class="time-options" role="group" :aria-label="activeTime === 'hour' ? '选择小时' : '选择分钟'">
        <button v-for="n in activeTime === 'hour' ? 24 : 60" :key="n" type="button" :aria-pressed="pad(n - 1) === (activeTime === 'hour' ? hour : minute)" @click="chooseTime(n - 1)">{{ pad(n - 1) }}</button>
      </div>
      <p class="time-hint">直接输入时分，或点击箭头展开全部选项</p>
      <p class="selection" :class="{ invalid: !validTime }" aria-live="polite">{{ validTime ? `已选：${date} ${pad(Number(hour))}:${pad(Number(minute))}` : '请输入有效时间：小时 00–23，分钟 00–59' }}</p>
      <footer><button type="button" @click="clear">清空</button><div><button type="button" @click="dialog?.close()">取消</button><button type="button" class="confirm" :disabled="!validTime" @click="confirm">确定</button></div></footer>
    </dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, useId } from 'vue'
const props = defineProps<{ modelValue: string; label: string; placeholder: string; defaultTime?: string }>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()
const dialog = ref<HTMLDialogElement>()
const inputId = useId()
const activeTime = ref<'hour' | 'minute' | null>(null)
function toggleTime(part: 'hour' | 'minute') { activeTime.value = activeTime.value === part ? null : part }
function selectInput(event: FocusEvent) { (event.target as HTMLInputElement).select() }
function chooseTime(value: number) {
  const part = activeTime.value
  if (part === 'hour') hour.value = pad(value)
  if (part === 'minute') minute.value = pad(value)
  activeTime.value = null
  dialog.value?.querySelector<HTMLInputElement>(part === 'hour' ? 'input[aria-label="小时"]' : 'input[aria-label="分钟"]')?.focus()
}
const validHour = computed(() => /^\d{1,2}$/.test(hour.value) && Number(hour.value) <= 23)
const validMinute = computed(() => /^\d{1,2}$/.test(minute.value) && Number(minute.value) <= 59)
const validTime = computed(() => validHour.value && validMinute.value)
function normalizeTime() {
  if (validHour.value) hour.value = pad(Number(hour.value))
  if (validMinute.value) minute.value = pad(Number(minute.value))
}
const year = ref(2026), month = ref(0), date = ref(''), hour = ref('00'), minute = ref('00'), today = ref('')
const pad = (value: number) => String(value).padStart(2, '0')
const dateValue = (value: Date) => `${value.getFullYear()}-${pad(value.getMonth() + 1)}-${pad(value.getDate())}`
const dayValue = (day: number) => `${year.value}-${pad(month.value + 1)}-${pad(day)}`
const offset = computed(() => (new Date(year.value, month.value, 1).getDay() + 6) % 7)
const days = computed(() => new Date(year.value, month.value + 1, 0).getDate())
function open() {
  activeTime.value = null
  const now = new Date()
  const selected = props.modelValue ? new Date(props.modelValue) : now
  today.value = dateValue(now)
  year.value = selected.getFullYear(); month.value = selected.getMonth(); date.value = dateValue(selected)
  const time = props.modelValue ? props.modelValue.slice(11, 16) : (props.defaultTime || `${pad(now.getHours())}:${pad(now.getMinutes())}`)
  hour.value = time.slice(0, 2); minute.value = time.slice(3, 5)
  dialog.value?.showModal()
}
function moveMonth(delta: number) { const next = new Date(year.value, month.value + delta, 1); year.value = next.getFullYear(); month.value = next.getMonth() }
function chooseDay(delta: number) { const next = new Date(); next.setDate(next.getDate() + delta); date.value = dateValue(next); year.value = next.getFullYear(); month.value = next.getMonth() }
function confirm() { if (!validTime.value) return; normalizeTime(); emit('update:modelValue', `${date.value}T${hour.value}:${minute.value}`); dialog.value?.close() }
function clear() { emit('update:modelValue', ''); dialog.value?.close() }
function closeOnBackdrop(event: MouseEvent) {
  if (event.target !== dialog.value || !dialog.value) return
  const rect = dialog.value.getBoundingClientRect()
  if (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom) dialog.value.close()
}
</script>

<style scoped>
.date-time-picker { min-width:0; }
button,input { font:inherit; cursor:pointer; }
button { border:0; background:transparent; color:#655d69; border-radius:8px; }
button:focus-visible,input:focus-visible { outline:3px solid #c8b8ed; outline-offset:2px; }
.picker-trigger { display:flex; align-items:center; justify-content:space-between; gap:8px; width:100%; min-height:48px; padding:12px; border:1px solid #e5dfed; border-radius:11px; background:#fdfcfe; font-size:13px; text-align:left; white-space:nowrap; }
.picker-trigger:hover { border-color:#9b80e2; background:#f8f5ff; }.picker-trigger.empty { color:#948b9e; }
.picker-dialog { position:fixed; inset:0; margin:auto; box-sizing:border-box; width:min(360px,calc(100vw - 32px)); max-height:calc(100dvh - 32px); overflow:auto; padding:20px; border:1px solid #e9e2f3; border-radius:18px; color:#40344e; background:#fff; box-shadow:0 20px 80px #34214740; font-size:14px; }
.picker-dialog::backdrop { background:#29223855; }
header,.month-navigation,.time-row,footer,footer div { display:flex; align-items:center; justify-content:space-between; gap:10px; }header strong { font-size:16px; }header button { font-size:24px; width:32px; height:32px; }.month-navigation { margin:14px 0; }.month-navigation button { width:36px; height:36px; background:#f6f2fb; font-size:24px; }
.calendar { display:grid; grid-template-columns:repeat(7,minmax(0,1fr)); gap:4px; text-align:center; }.calendar button,.weekday { display:grid; place-items:center; height:36px; }.weekday { color:#aaa0b3; font-size:12px; }.calendar button:hover { background:#f1eafa; }.calendar button.today { box-shadow:inset 0 0 0 1px #bda7e9; }.calendar button.selected { background:#7657d5; color:white; }
.shortcuts { display:flex; gap:8px; margin:14px 0; }.shortcuts button { padding:7px 16px; background:#f4effb; color:#7657d5; }.time-row { justify-content:flex-start; padding-top:14px; border-top:1px solid #eee8f3; }.time-row>span:first-child { margin-right:auto; }.time-row input { box-sizing:border-box; width:52px; min-width:0; cursor:text; padding:8px; border:1px solid #e5dfed; border-radius:8px; background:white; color:#40344e; }.selection { color:#8a8096; font-size:12px; margin:14px 0; }footer { padding-top:14px; border-top:1px solid #eee8f3; }footer button { padding:9px 14px; }footer .confirm { color:white; background:#7657d5; }
.time-hint { margin:8px 0 0; color:#8a8096; font-size:12px; }.selection { min-height:18px; }.selection.invalid { color:#c7475e; }.time-row input[aria-invalid="true"] { border-color:#c7475e; }footer .confirm:disabled { opacity:.45; cursor:not-allowed; }
.time-input { display:flex; align-items:center; border:1px solid #e5dfed; border-radius:8px; overflow:hidden; }.time-input input { border:0; border-radius:0; }.time-input button { width:26px; min-height:36px; border-radius:0; background:#f6f2fb; }.time-input:focus-within { outline:2px solid #c8b8ed; outline-offset:2px; }.time-input input:focus-visible { outline:0; }.time-options { display:grid; grid-template-columns:repeat(6,minmax(0,1fr)); gap:4px; max-height:144px; overflow-y:auto; overscroll-behavior:contain; margin-top:10px; padding:8px; border:1px solid #e5dfed; border-radius:10px; background:#fcfaff; }.time-options button { min-height:32px; flex-shrink:0; }.time-options button:hover { background:#eee5fa; }.time-options button[aria-pressed="true"] { color:#fff; background:#7657d5; }
</style>
