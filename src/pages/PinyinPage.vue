<template>
  <div class="page pinyin-page">
    <header class="pinyin-header">
      <div class="header-copy">
        <RouterLink v-if="!auth.isTeacher" to="/">‹ 返回宠物乐园</RouterLink>
        <h1>拼音探险</h1>
        <p>选一课，点卡片听一听。</p>
      </div>
      <div class="header-pet" aria-hidden="true">
        <span class="pet-star">✦</span>
        <img :src="getPetImage('云朵猫', 2)" width="144" height="144" alt="" />
        <span class="pet-star pet-star-small">✧</span>
      </div>
    </header>

    <div class="pinyin-layout">
      <nav class="lesson-list" aria-label="拼音课程">
        <h2>选一课</h2>
        <div class="lesson-options">
          <button
            v-for="(item, index) in pinyinLessons"
            :key="item.title"
            type="button"
            :aria-current="current === index ? 'step' : undefined"
            @click="selectLesson(index)"
          >
            <span class="lesson-number" :aria-label="'第 ' + (index + 1) + ' 课'">{{ index + 1 }}</span>
            <span class="lesson-label">
              <strong>{{ item.title }}</strong>
              <small>{{ item.category }}</small>
            </span>
          </button>
        </div>
      </nav>

      <section class="lesson-content" aria-labelledby="lesson-title">
        <p class="lesson-category">第 {{ current + 1 }} 课 · {{ lesson.category }}</p>
        <h2 id="lesson-title">{{ lesson.title }}</h2>
        <div v-for="(group, index) in soundGroups" :key="index" class="sound-group">
          <h3 v-if="group.title">{{ group.title }}</h3>
          <div class="sound-grid" :class="{ 'sound-grid-six': group.sounds.length === 6 }">
            <button
              v-for="[pinyin, recording] in group.sounds"
              :key="pinyin"
              type="button"
              class="sound-card"
              :class="{ 'is-playing': activeSound === pinyin }"
              :aria-label="'播放 ' + pinyin + ' 的读音'"
              @click="playSound(pinyin, recording)"
            >
              <strong>{{ pinyin }}</strong>
              <span class="sound-icon" aria-hidden="true">🔊</span>
            </button>
          </div>
        </div>

        <template v-if="blend">
          <p>{{ lesson.title }}，合起来读成一个音节。</p>
          <div class="blend-demo">
            <div class="blend" aria-live="polite">
              <div class="blend-parts">
                <template v-for="(part, index) in blend.parts" :key="index">
                  <span v-if="index > 0" class="blend-symbol" aria-hidden="true">+</span>
                  <div
                    class="blend-tile"
                    :class="{ 'playing-part': activePart === index }"
                    :data-part="index === 0 ? 'initial' : index === blend.parts.length - 1 ? 'final' : 'medial'"
                  >
                    <small>{{ index === 0 ? '声母' : index === blend.parts.length - 1 ? '韵母' : '介母' }}</small>
                    <strong>{{ part }}</strong>
                  </div>
                </template>
              </div>
              <div class="blend-merge">
                <span class="blend-symbol" aria-hidden="true">→</span>
                <button
                  type="button"
                  class="sound-card blend-result"
                  :class="{ 'is-playing': activeSound === blend.pinyin }"
                  :aria-label="'示范拼读 ' + blend.pinyin"
                  @click="playBlend(blend)"
                >
                  <strong>{{ blend.pinyin }}</strong>
                  <span class="blend-play"><span aria-hidden="true">🔊</span> 听拼读</span>
                </button>
              </div>
            </div>
            <button type="button" class="shuffle-button" @click="shuffleBlend">
              <span aria-hidden="true">↻</span> 随机换一个
            </button>
          </div>
        </template>
        <p class="audio-status" role="status">{{ audioMessage }}</p>
      </section>
    </div>
    <details class="audio-credit">
      <summary>素材许可</summary>
      <p>
        声母和韵母录音来自
        <a href="https://language.moe.gov.tw/001/Upload/files/site_content/M0001/juyin/" target="_blank" rel="noopener noreferrer">台湾教育部《国语注音符号手册》</a>，
        采用 <a href="https://creativecommons.org/licenses/by/4.0/" target="_blank" rel="noopener noreferrer">CC BY 4.0</a> 许可。
      </p>
    </details>
  </div>
</template>

<script setup lang="ts">
import { computed, onUnmounted, ref } from 'vue'
import { getPetImage } from '../lib/constants'
import { pinyinLessons } from '../lib/pinyinLessons'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const storageKey = `pinyin:last-lesson-v4:${auth.user?.id}`
const current = ref(0)
try {
  const savedValue = localStorage.getItem(storageKey)
  const saved = Number(savedValue)
  if (savedValue === null) {
    const previousValue = localStorage.getItem(`pinyin:last-lesson-v3:${auth.user?.id}`)
    const originalIndex = Number(localStorage.getItem(`pinyin:last-lesson-v2:${auth.user?.id}`))
    const mergedLessonIndices = [0, 0, 1, 2, 2, 3, 4, 5, 6]
    const previousIndex = previousValue === null ? mergedLessonIndices[originalIndex] ?? 0 : Number(previousValue)
    const shiftedLessonIndices = [0, 1, 2, 3, 5, 6, 7]
    current.value = shiftedLessonIndices[previousIndex] ?? 0
  } else if (Number.isInteger(saved) && saved >= 0 && saved < pinyinLessons.length) {
    current.value = saved
  }
} catch {
  // The lesson remains available when browser storage is blocked.
}
const lesson = computed(() => pinyinLessons[current.value]!)
const soundGroups = computed(() => 'soundGroups' in lesson.value ? lesson.value.soundGroups : [])
const recordings = new Map<string, number>(
  pinyinLessons.flatMap(item => 'soundGroups' in item ? item.soundGroups : [])
    .flatMap(group => group.sounds),
)
const blendIndex = ref(-1)
const blend = computed(() => {
  if (!('blends' in lesson.value)) return
  const entry = lesson.value.blends[blendIndex.value]
  if (!entry) return
  const parts = entry.slice(0, -1)
  return { parts, pinyin: parts.join(''), character: entry[entry.length - 1]! }
})
const audioMessage = ref('')
const activePart = ref<number | null>(null)
const activeSound = ref<string | null>(null)
let reading: SpeechSynthesisUtterance | undefined
let recordingAudio: HTMLAudioElement | undefined
shuffleBlend()

function stopAudio() {
  const previous = recordingAudio
  recordingAudio = undefined
  previous?.pause()
  activePart.value = null
  activeSound.value = null
  if (reading) {
    reading = undefined
    window.speechSynthesis.cancel()
  }
}

function playSound(pinyin: string, recording: number, onEnd?: () => void) {
  if (!onEnd) stopAudio()
  const audio = new Audio(`${import.meta.env.BASE_URL}assets/pinyin/${recording}.wav`)
  recordingAudio = audio
  activeSound.value = pinyin
  audioMessage.value = `正在播放 ${pinyin}`

  const finish = (message: string) => {
    if (recordingAudio !== audio) return
    recordingAudio = undefined
    activeSound.value = null
    audioMessage.value = message
    if (message) activePart.value = null
    else onEnd?.()
  }
  const fail = () => finish('录音播放失败，请再试一次。')
  audio.onended = () => finish('')
  audio.onerror = fail
  void audio.play().catch(fail)
}

function playBlend({ parts, pinyin, character }: NonNullable<typeof blend.value>) {
  stopAudio()

  function playPart(index: number) {
    const part = parts[index]
    if (part === undefined) {
      speak(character, pinyin)
      return
    }

    const key = part.normalize('NFD').replace(/[\u0300\u0301\u0304\u030c]/g, '').normalize('NFC')
    const recording = recordings.get(key)
    if (recording === undefined) {
      activePart.value = null
      audioMessage.value = `缺少 ${part} 的分段录音。`
      return
    }

    activePart.value = index
    playSound(key, recording, () => playPart(index + 1))
  }

  playPart(0)
}

function selectLesson(index: number) {
  stopAudio()
  current.value = index
  audioMessage.value = ''
  blendIndex.value = -1
  shuffleBlend()
  try {
    localStorage.setItem(storageKey, String(index))
  } catch {
    // Switching lessons does not depend on persistence.
  }
}

function shuffleBlend() {
  if (!('blends' in lesson.value)) return
  stopAudio()
  audioMessage.value = ''

  const count = lesson.value.blends.length
  const previous = blendIndex.value
  const canExcludePrevious = previous >= 0 && count > 1
  const next = Math.floor(Math.random() * (count - Number(canExcludePrevious)))
  blendIndex.value = canExcludePrevious && next >= previous ? next + 1 : next
}

function speak(example: string, pinyin: string) {
  stopAudio()
  if (!('speechSynthesis' in window) || !('SpeechSynthesisUtterance' in window)) {
    audioMessage.value = '当前浏览器不支持语音播放。'
    return
  }

  const speech = window.speechSynthesis
  const utterance = new SpeechSynthesisUtterance(example)
  const voices = speech.getVoices()
  const voice = voices.find(item => /^(zh|cmn)([-_]Hans)?[-_]CN$/i.test(item.lang))
  if (!voice && voices.length > 0) {
    audioMessage.value = '当前设备没有中国大陆普通话语音（zh-CN）。'
    return
  }
  utterance.lang = 'zh-CN'
  if (voice) utterance.voice = voice
  utterance.rate = 0.85
  utterance.onend = () => {
    if (reading !== utterance) return
    reading = undefined
    activeSound.value = null
    audioMessage.value = ''
  }
  utterance.onerror = () => {
    if (reading !== utterance) return
    reading = undefined
    activeSound.value = null
    audioMessage.value = '语音播放失败，请检查设备是否已安装普通话语音。'
  }
  reading = utterance
  activeSound.value = pinyin
  audioMessage.value = `正在播放 ${pinyin}`
  speech.speak(utterance)
}

onUnmounted(stopAudio)
</script>

<style scoped>
.pinyin-page {
  --ink: #352953;
  --purple: #5d3996;
  --lavender: #eee5ff;
  width: min(100%, 1150px);
  max-width: 1150px;
  margin-inline: auto;
  color: var(--ink);
}
.pinyin-header {
  position: relative;
  isolation: isolate;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 24px;
  padding: 22px clamp(18px, 4vw, 48px);
  overflow: hidden;
  border: 1px solid #dcd0f4;
  border-radius: 32px;
  background: radial-gradient(ellipse at 86% 36%, #fff8dc 0%, #f4e4ff 38%, #e7dbfb 80%);
}
.header-copy a { color: var(--purple); font-weight: 700; }
.header-copy h1 { margin: 8px 0 4px; font-size: clamp(1.8rem, 4.2vw, 3.2rem); line-height: 1.12; }
.header-copy p { margin: 0; color: #533f71; }
.header-pet { position: relative; flex: 0 0 auto; }
.header-pet img { display: block; width: clamp(76px, 15vw, 144px); height: auto; object-fit: contain; }
.pet-star { position: absolute; color: #9c6400; font-size: 1.4rem; inset: 0 0 auto auto; }
.pet-star-small { inset: auto auto 10% -8%; font-size: 1.15rem; }
.pinyin-layout { display: grid; grid-template-columns: 228px minmax(0, 1fr); align-items: start; gap: 20px; }
.lesson-list, .lesson-content {
  padding: 16px;
  background: #fffdfb;
  border: 1px solid #e8dff1;
  border-radius: 24px;
}
.lesson-list h2 { margin: 0 0 12px; font-size: 1.1rem; }
.lesson-options { display: grid; gap: 8px; }
.lesson-options button {
  display: grid;
  grid-template-columns: 32px minmax(0, 1fr);
  align-items: center;
  gap: 10px;
  min-height: 54px;
  padding: 7px 9px;
  text-align: left;
  border: 1px solid #e8dff1;
  border-radius: 14px;
  color: inherit;
  background: #fff;
  cursor: pointer;
}
.lesson-options button[aria-current] { border-color: #9776ce; background: var(--lavender); }
.lesson-number {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border-radius: 11px;
  background: var(--lavender);
  color: var(--purple);
  font-weight: 800;
}
[aria-current] .lesson-number { color: #fff; background: var(--purple); }
.lesson-label strong, .lesson-label small { display: block; }
.lesson-label small { margin-top: 2px; color: #635575; }
.lesson-content { padding: clamp(16px, 3.5vw, 36px); }
.lesson-category { margin: 0 0 5px; color: var(--purple); font-size: .86rem; font-weight: 700; }
.lesson-content h2 { margin: 0 0 20px; font-size: clamp(1.5rem, 4vw, 2.4rem); line-height: 1.2; }
.sound-grid { display: grid; max-width: 680px; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 14px; }
.sound-grid-six { grid-template-columns: repeat(3, minmax(0, 1fr)); }
.sound-group + .sound-group { margin-top: 20px; }
.sound-group h3 { margin: 0 0 10px; font-size: 1.05rem; color: var(--purple); }
.sound-card {
  --tile: #efe5ff;
  --edge: #c6abe9;
  --tile-ink: #4e327a;
  display: grid;
  justify-items: center;
  align-content: center;
  gap: 5px;
  min-height: 124px;
  padding: 12px;
  border: 1px solid var(--edge);
  border-bottom-width: 4px;
  border-radius: 22px;
  background: var(--tile);
  color: var(--tile-ink);
  cursor: pointer;
}
.sound-grid .sound-card:nth-child(3n + 2) { --tile: #ffe8bb; --edge: #e9ba62; --tile-ink: #704500; }
.sound-grid .sound-card:nth-child(3n) { --tile: #d8f5e7; --edge: #95cdb6; --tile-ink: #245747; }
.sound-card strong { font-size: clamp(2.2rem, 6vw, 3.5rem); line-height: 1.15; }
.sound-icon { display: grid; place-items: center; width: 34px; height: 34px; border-radius: 50%; background: #fff; font-size: 1rem; }
.sound-card:hover, .sound-card.is-playing { border-color: currentColor; }
.sound-card.is-playing .sound-icon { box-shadow: 0 0 0 2px currentColor; }
.pinyin-page :is(button, a, summary):focus-visible { outline: 3px solid var(--purple); outline-offset: 3px; }
.blend-demo {
  display: grid;
  justify-items: center;
  gap: 18px;
  margin-top: 16px;
  padding: clamp(12px, 4vw, 32px);
  border: 1px solid #e6d9f8;
  border-radius: 24px;
  background: radial-gradient(circle at 82% 14%, #fff4d9, #f7efff 68%);
}
.blend, .blend-parts, .blend-merge { display: flex; align-items: center; justify-content: center; gap: 8px; }
.blend { flex-wrap: wrap; column-gap: 12px; row-gap: 14px; max-width: 100%; }
.blend-tile {
  display: grid;
  place-content: center;
  justify-items: center;
  min-width: clamp(58px, 9vw, 92px);
  min-height: clamp(72px, 12vw, 108px);
  padding: 6px;
  border: 1px solid var(--part-edge);
  border-bottom-width: 4px;
  border-radius: 18px;
  background: var(--part-bg);
  color: var(--part-ink);
}
.blend-tile[data-part="initial"] { --part-bg: #ffe6f0; --part-edge: #e3a9c3; --part-ink: #843c62; }
.blend-tile[data-part="medial"] { --part-bg: #ffe8bb; --part-edge: #e9ba62; --part-ink: #704500; }
.blend-tile[data-part="final"] { --part-bg: #d8f5e7; --part-edge: #95cdb6; --part-ink: #245747; }
.blend-tile small { font-size: .75rem; font-weight: 700; }
.blend-tile strong { font-size: clamp(1.6rem, 5vw, 2.65rem); line-height: 1.12; }
.blend-symbol { color: var(--purple); font-size: clamp(1rem, 3vw, 1.75rem); font-weight: 800; }
.blend-result { min-width: clamp(100px, 15vw, 145px); min-height: 100px; }
.blend-result strong { font-size: clamp(2rem, 6vw, 3.35rem); }
.blend-play { font-size: .82rem; font-weight: 700; }
.playing-part { border-color: currentColor; box-shadow: 0 0 0 2px currentColor; }
.shuffle-button { min-height: 44px; padding: 9px 15px; border: 1px solid #7b56b2; border-radius: 14px; background: var(--purple); color: #fff; font-weight: 700; cursor: pointer; }
.audio-status { margin: 0; color: var(--purple); }
.audio-status:not(:empty) { margin-top: 14px; }
.audio-credit { width: fit-content; margin: 16px 0 0 auto; font-size: .78rem; color: #635575; }
.audio-credit summary { cursor: pointer; }
.audio-credit p { margin: 6px 0 0; }
.audio-credit a { color: inherit; }
@media (max-width: 650px) {
  .pinyin-header { margin-bottom: 16px; border-radius: 24px; }
  .pinyin-layout { grid-template-columns: minmax(0, 1fr); gap: 14px; }
  .lesson-options { grid-auto-flow: column; grid-auto-columns: minmax(134px, 42%); overflow-x: auto; padding: 4px; }
  .sound-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; }
  .sound-card { min-height: 100px; padding: 8px; border-radius: 16px; }
}
</style>
