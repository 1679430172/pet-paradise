<template>
  <div class="page">
    <h1 class="page-title">成长日记</h1>

    <router-link to="/diary/new" class="new-diary-btn btn btn-primary">
      ✏️ 写日记
    </router-link>

    <div v-if="diaryStore.loading" class="loading">加载中...</div>

    <div v-else-if="diaryStore.entries.length === 0" class="empty">
      <span class="empty-icon">📝</span>
      <p>还没有日记哦，快来记录宠物的成长吧！</p>
    </div>

    <div v-else class="diary-list">
      <div v-for="entry in diaryStore.entries" :key="entry.id" class="diary-card card" @click="router.push(`/diary/${entry.id}`)">
        <div class="diary-header">
          <span class="diary-mood">{{ getMoodIcon(entry.mood) }}</span>
          <h3 class="diary-title">{{ entry.title }}</h3>
          <span class="diary-date">{{ formatDate(entry.created_at) }}</span>
        </div>
        <p class="diary-content">{{ entry.content.slice(0, 60) }}{{ entry.content.length > 60 ? '...' : '' }}</p>
        <img v-if="entry.image_url" :src="entry.image_url" class="diary-thumb" alt="" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useDiaryStore } from '../stores/diary'
import { MOODS } from '../lib/constants'

const router = useRouter()
const diaryStore = useDiaryStore()

function getMoodIcon(mood: string) {
  return MOODS.find(m => m.value === mood)?.icon ?? '😊'
}

function formatDate(dateStr: string) {
  const d = new Date(dateStr)
  return `${d.getMonth() + 1}/${d.getDate()}`
}

onMounted(() => {
  diaryStore.fetchMyEntries()
})
</script>

<style scoped>
.new-diary-btn {
  display: block;
  text-align: center;
  margin-bottom: 20px;
}

.loading, .empty {
  text-align: center;
  padding: 48px 0;
  color: var(--color-text-muted);
}

.empty-icon {
  font-size: 3rem;
  display: block;
  margin-bottom: 12px;
}

.diary-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.diary-card {
  cursor: pointer;
  transition: transform 0.2s;
}

.diary-card:hover {
  transform: translateY(-2px);
}

.diary-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}

.diary-mood {
  font-size: 1.3rem;
}

.diary-title {
  flex: 1;
  font-size: 1rem;
  font-family: var(--font-body);
}

.diary-date {
  font-size: 0.75rem;
  color: var(--color-text-muted);
}

.diary-content {
  font-size: 0.85rem;
  color: var(--color-text-muted);
  line-height: 1.5;
}

.diary-thumb {
  width: 100%;
  height: 120px;
  object-fit: cover;
  border-radius: var(--radius-sm);
  margin-top: 10px;
}
</style>
