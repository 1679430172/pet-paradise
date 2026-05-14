<template>
  <div class="create-page">
    <div class="create-header">
      <h1>{{ petStore.pets.length > 0 ? '领养新伙伴' : '选择你的宠物' }}</h1>
      <p>选一个可爱的伙伴陪伴你吧！</p>
    </div>

    <!-- 种类选择 -->
    <div class="species-grid">
      <div
        v-for="s in PET_SPECIES"
        :key="s"
        class="species-card"
        :class="{ selected: species === s }"
        @click="species = s"
      >
        <span class="species-icon">{{ speciesIcons[s] }}</span>
        <span class="species-name">{{ PET_SPECIES_LABELS[s] }}</span>
      </div>
    </div>

    <!-- 颜色选择 -->
    <div class="section">
      <h3>选择颜色</h3>
      <div class="color-grid">
        <div
          v-for="c in PET_COLORS"
          :key="c"
          class="color-dot"
          :class="{ selected: color === c }"
          :style="{ background: c }"
          @click="color = c"
        />
      </div>
    </div>

    <!-- 取名 -->
    <div class="section">
      <h3>给它取个名字</h3>
      <input
        v-model="name"
        type="text"
        class="form-input"
        placeholder="输入宠物的名字"
        maxlength="10"
      />
    </div>

    <!-- 预览 -->
    <div class="preview card" v-if="species" :style="{ background: color }">
      <PetAvatar
        class="preview-pet"
        :species="species"
        :level="1"
        :size="120"
        show-stage
      />
      <p class="preview-name">{{ name || '未命名' }}</p>
      <p class="preview-hint">新生宠物从「蛋」开始成长</p>
    </div>

    <p v-if="errorMsg" class="form-error">{{ errorMsg }}</p>

    <button
      class="btn btn-primary create-btn"
      :disabled="!species || !name || loading"
      @click="handleCreate"
    >
      {{ loading ? '领养中...' : '领养它！' }}
    </button>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { usePetStore } from '../stores/pet'
import { PET_SPECIES, PET_SPECIES_LABELS, PET_COLORS } from '../lib/constants'
import PetAvatar from '../components/pet/PetAvatar.vue'

const router = useRouter()
const petStore = usePetStore()

const species = ref('')
const color = ref(PET_COLORS[0])
const name = ref('')
const loading = ref(false)
const errorMsg = ref('')

const speciesIcons: Record<string, string> = {
  cat: '🐱',
  dog: '🐶',
  rabbit: '🐰',
  hamster: '🐹',
  bird: '🐦',
  turtle: '🐢',
}

onMounted(async () => {
  if (petStore.pets.length === 0) {
    await petStore.fetchPets()
  }
  if (!petStore.canAdoptNew) {
    errorMsg.value = '当前宠物尚未达到完全体（Lv.20），暂不能领养新宠物'
    setTimeout(() => router.replace('/'), 1200)
  }
})

async function handleCreate() {
  if (!species.value || !name.value) return
  errorMsg.value = ''
  loading.value = true
  const { error } = await petStore.createPet(name.value, species.value, color.value) ?? {}
  loading.value = false
  if (error) {
    errorMsg.value = error.message || '领养失败'
    return
  }
  router.push('/')
}
</script>

<style scoped>
.create-page {
  min-height: 100vh;
  padding: 32px 20px;
  max-width: 480px;
  margin: 0 auto;
}

.create-header {
  text-align: center;
  margin-bottom: 28px;
}

.create-header h1 {
  font-size: 1.8rem;
  color: var(--color-primary);
}

.create-header p {
  color: var(--color-text-muted);
  margin-top: 6px;
}

.species-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
  margin-bottom: 28px;
}

.species-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  padding: 16px 8px;
  background: white;
  border: 2px solid var(--color-border);
  border-radius: var(--radius);
  cursor: pointer;
  transition: all 0.2s;
}

.species-card.selected {
  border-color: var(--color-primary);
  background: #FFF0F5;
  transform: scale(1.05);
}

.species-icon {
  font-size: 2.2rem;
}

.species-name {
  font-size: 0.85rem;
  color: var(--color-text-muted);
}

.section {
  margin-bottom: 24px;
}

.section h3 {
  font-size: 1rem;
  margin-bottom: 12px;
  color: var(--color-text);
}

.color-grid {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.color-dot {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  cursor: pointer;
  border: 3px solid transparent;
  transition: all 0.2s;
}

.color-dot.selected {
  border-color: var(--color-text);
  transform: scale(1.2);
}

.preview {
  text-align: center;
  margin: 24px 0;
}

.preview-pet {
  margin: 0 auto 12px;
}

.preview-icon {
  font-size: 3rem;
}

.preview-name {
  font-family: var(--font-fun);
  font-size: 1.2rem;
}

.preview-hint {
  font-size: 0.72rem;
  color: var(--color-text-muted);
  margin-top: 4px;
}

.form-error {
  color: var(--color-danger, #e74c3c);
  font-size: 0.85rem;
  text-align: center;
  margin: 8px 0;
}

.create-btn {
  width: 100%;
  padding: 16px;
  font-size: 1.1rem;
}
</style>
