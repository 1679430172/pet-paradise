<template>
  <div class="page pinyin-page">
    <header class="pinyin-header">
      <div class="header-copy">
        <RouterLink v-if="!auth.isTeacher" to="/">‹ 返回宠物乐园</RouterLink>
        <h1>拼音探险</h1>
        <p>选一课，看一看拼音在四线三格里的位置。</p>
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
            <strong v-for="pinyin in group.sounds" :key="pinyin" class="pinyin-ruled">{{ pinyin }}</strong>
          </div>
        </div>

        <template v-if="blend">
          <p>{{ lesson.title }}，合起来读成一个音节。</p>
          <div class="blend-demo">
            <div class="blend" aria-live="polite">
              <div class="blend-parts">
                <template v-for="(part, index) in blend.parts" :key="index">
                  <span v-if="index > 0" class="blend-symbol" aria-hidden="true">+</span>
                  <div class="blend-tile">
                    <small>{{ index === 0 ? '声母' : index === blend.parts.length - 1 ? '韵母' : '介母' }}</small>
                    <strong class="pinyin-ruled">{{ part }}</strong>
                  </div>
                </template>
              </div>
              <div class="blend-merge">
                <span class="blend-symbol" aria-hidden="true">→</span>
                <div class="blend-tile blend-result">
                  <strong class="pinyin-ruled">{{ blend.pinyin }}</strong>
                </div>
              </div>
            </div>
            <button type="button" class="shuffle-button" @click="shuffleBlend">
              <span aria-hidden="true">↻</span> 随机换一个
            </button>
          </div>
        </template>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
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
const blendIndex = ref(-1)
const blend = computed(() => {
  if (!('blends' in lesson.value)) return
  const parts = lesson.value.blends[blendIndex.value]
  if (!parts) return
  return { parts, pinyin: parts.join('') }
})
shuffleBlend()

function selectLesson(index: number) {
  current.value = index
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

  const count = lesson.value.blends.length
  const previous = blendIndex.value
  const canExcludePrevious = previous >= 0 && count > 1
  const next = Math.floor(Math.random() * (count - Number(canExcludePrevious)))
  blendIndex.value = canExcludePrevious && next >= previous ? next + 1 : next
}
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
.sound-grid {
  --cell-width: 112px;
  display: grid;
  grid-template-columns: repeat(4, minmax(0, var(--cell-width)));
  gap: 32px 14px;
  text-align: center;
}
.sound-grid-six { grid-template-columns: repeat(3, minmax(0, var(--cell-width))); }
.sound-group + .sound-group { margin-top: 20px; }
.sound-group h3 { margin: 0 0 10px; font-size: 1.05rem; color: var(--purple); }
.blend-tile { display: grid; gap: 6px; padding: 8px; text-align: center; }
.pinyin-ruled {
  --rule: #a59ab2;
  --line: linear-gradient(var(--rule), var(--rule));
  display: block;
  box-sizing: border-box;
  height: 1.62em;
  border: 1px solid var(--rule);
  background:
    var(--line) center 33.333% / 100% 1px,
    var(--line) center 66.667% / 100% 1px;
  background-repeat: no-repeat;
  font: 400 clamp(1.75rem, 5vw, 2.75rem) / 0 Arial, sans-serif;
  white-space: nowrap;
}
.pinyin-ruled::before {
  /* Align the letters' baseline with the third rule. */
  display: inline-block;
  height: calc(66.667% + 0.333px);
  content: '';
}
.pinyin-page :is(button, a, summary):focus-visible { outline: 3px solid var(--purple); outline-offset: 3px; }
.blend-demo {
  display: grid;
  justify-items: center;
  gap: 18px;
  margin-top: 16px;
  padding: clamp(12px, 4vw, 32px);
}
.blend, .blend-parts, .blend-merge { display: flex; align-items: flex-start; justify-content: center; gap: 8px; }
.blend { flex-wrap: wrap; column-gap: 12px; row-gap: 14px; max-width: 100%; }
.blend-tile { min-width: clamp(52px, 9vw, 92px); }
.blend-tile small { font-size: .75rem; line-height: 1.25rem; }
.blend-symbol {
  align-self: flex-start;
  margin-top: calc(1.25rem + 14px + .81 * clamp(1.75rem, 5vw, 2.75rem));
  transform: translateY(-50%);
  color: var(--purple);
  font-size: 1.15rem;
}
.blend-result { min-width: clamp(100px, 15vw, 145px); padding-top: calc(1.25rem + 14px); }
.shuffle-button { min-height: 44px; padding: 9px 15px; border: 1px solid #7b56b2; border-radius: 14px; background: var(--purple); color: #fff; font-weight: 700; cursor: pointer; }
@media (max-width: 650px) {
  .pinyin-header { margin-bottom: 16px; border-radius: 24px; }
  .pinyin-layout { grid-template-columns: minmax(0, 1fr); gap: 14px; }
  .lesson-options { grid-auto-flow: column; grid-auto-columns: minmax(134px, 42%); overflow-x: auto; padding: 4px; }
  .sound-grid { --cell-width: 96px; grid-template-columns: repeat(2, minmax(0, var(--cell-width))); gap: 24px 8px; }
  .blend-demo { padding-inline: 0; }
  .blend-parts { gap: 4px; }
}
</style>
