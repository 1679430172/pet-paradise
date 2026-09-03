<template>
  <div class="pet-color-picker" role="group" aria-label="选择宠物背景色">
    <button v-for="(c, index) in PET_COLORS" :key="c" type="button"
      class="theme-option" :class="{ selected: modelValue === c }"
      :aria-label="`选择${PET_COLOR_NAMES[index]}`" :aria-pressed="modelValue === c"
      @click="modelValue = c">
      <span class="theme-swatch" :style="getPetThemeStyle(c)">
        <span v-if="modelValue === c" class="theme-check" aria-hidden="true">✓</span>
      </span>
      <span class="theme-label">{{ PET_COLOR_NAMES[index] }}</span>
    </button>
  </div>
</template>

<script setup lang="ts">
import { PET_COLORS } from '../../lib/constants'
import { getPetThemeStyle, PET_COLOR_NAMES } from '../../lib/petTheme'
const modelValue = defineModel<string>({ required: true })
</script>

<style scoped>
.pet-color-picker { display: flex; flex-wrap: wrap; gap: 10px; }
.theme-option { display: flex; flex-direction: column; align-items: center; gap: 7px; padding: 5px; background: none; border: 0; border-radius: 12px; color: #79847c; cursor: pointer; font: inherit; }
.theme-swatch { position: relative; display: block; width: 46px; height: 46px; border-radius: 14px; border: 1px solid #e3e9e5; box-shadow: 0 2px 6px #203e2c08; transition: box-shadow .18s, border-color .18s; }
.theme-label { font-size: 12px; white-space: nowrap; }
.theme-option:hover .theme-swatch { border-color: #91b8a2; box-shadow: 0 3px 10px #203e2c12; }
.theme-option.selected { color: #36795c; }
.theme-option.selected .theme-swatch { border: 2px solid #36795c; box-shadow: 0 0 0 3px #36795c14; }
.theme-check { position: absolute; right: -5px; bottom: -5px; display: grid; place-items: center; width: 18px; height: 18px; border: 2px solid white; border-radius: 50%; background: #36795c; color: white; font-size: 11px; }
.theme-option:focus-visible { outline: 2px solid #36795c; outline-offset: 2px; }
</style>
