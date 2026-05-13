<template>
  <div class="page">
    <div v-if="loading" class="loading">加载中...</div>
    <div v-else-if="entry" class="detail">
      <div class="detail-header">
        <button class="btn-back" @click="router.back()">← 返回</button>
      </div>
      <div class="detail-card card">
        <div class="detail-meta">
          <span class="detail-mood">{{ getMoodIcon(entry.mood) }}</span>
          <span class="detail-date">{{ formatDate(entry.created_at) }}</span>
        </div>
        <h2 class="detail-title">{{ entry.title }}</h2>
        <img v-if="entry.image_url" :src="entry.image_url" class="detail-image" alt="" />
        <p class="detail-content">{{ entry.content }}</p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { MOODS } from '../lib/constants'
import type { DiaryEntry } from '../stores/diary'

const route = useRoute()
const router = useRouter()
const entry = ref<DiaryEntry | null>(null)
const loading = ref(true)

function getMoodIcon(mood: string) {
  return MOODS.find(m => m.value === mood)?.icon ?? '😊'
}

function formatDate(dateStr: string) {
  const d = new Date(dateStr)
  return `${d.getFullYear()}/${d.getMonth() + 1}/${d.getDate()}`
}

onMounted(async () => {
  const { data } = await supabase
    .from('diary_entries')
    .select('*')
    .eq('id', route.params.id)
    .single()
  entry.value = data
  loading.value = false
})
</script>

<style scoped>
.loading {
  text-align: center;
  padding: 48px 0;
  color: var(--color-text-muted);
}

.detail-header {
  margin-bottom: 16px;
}

.btn-back {
  background: none;
  color: var(--color-primary);
  font-size: 0.9rem;
  padding: 4px 0;
}

.detail-card {
  padding: 24px;
}

.detail-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;
}

.detail-mood {
  font-size: 1.5rem;
}

.detail-date {
  font-size: 0.8rem;
  color: var(--color-text-muted);
}

.detail-title {
  font-size: 1.4rem;
  margin-bottom: 16px;
}

.detail-image {
  width: 100%;
  border-radius: var(--radius);
  margin-bottom: 16px;
}

.detail-content {
  font-size: 0.95rem;
  line-height: 1.8;
  color: var(--color-text);
  white-space: pre-wrap;
}
</style>
