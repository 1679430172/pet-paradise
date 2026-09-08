<template>
  <div class="page diary-page">
    <h1 class="page-title">日记广场</h1>

    <div class="diary-tabs" role="tablist" aria-label="日记广场">
      <button type="button" role="tab" :aria-selected="activeTab === 'mine'" :class="{ active: activeTab === 'mine' }" @click="switchTab('mine')">📖 我的日记</button>
      <button type="button" role="tab" :aria-selected="activeTab === 'square'" :class="{ active: activeTab === 'square' }" @click="switchTab('square')">🌍 班级广场</button>
    </div>

    <template v-if="activeTab === 'mine'">
      <router-link to="/diary/new" class="new-diary-btn btn btn-primary">✏️ 写日记</router-link>

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
    </template>

    <template v-else>
      <router-link to="/diary/new" class="new-diary-btn btn btn-primary">✏️ 写公开日记</router-link>
      <div v-if="feedStore.loading" class="loading">加载中...</div>
      <div v-else-if="feedStore.items.length === 0" class="empty">
        <span class="empty-icon">🌍</span>
        <p>还没有动态，快去写一篇公开日记吧！</p>
      </div>
      <div v-else class="feed-list">
        <div v-for="item in feedStore.items" :key="item.id" class="feed-card card">
          <div class="feed-header">
            <PetAvatar :species="item.pets?.species" :level="item.pets?.level || 1" :size="40" />
            <div class="feed-info">
              <span class="feed-username">{{ item.profiles?.username || '匿名' }}</span>
              <span class="feed-pet-name">{{ item.pets?.name }} · Lv.{{ item.pets?.level }}</span>
            </div>
            <span class="diary-date">{{ formatDate(item.created_at) }}</span>
          </div>
          <h3 class="feed-title">{{ getMoodIcon(item.mood) }} {{ item.title }}</h3>
          <p class="diary-content">{{ item.content.slice(0, 100) }}{{ item.content.length > 100 ? '...' : '' }}</p>
          <img v-if="item.image_url" :src="item.image_url" class="feed-image" alt="" />
          <div class="feed-actions">
            <button class="like-btn" :class="{ liked: item.liked_by_me }" @click="feedStore.toggleLike(item.id, item.owner_id)">
              {{ item.liked_by_me ? '❤️' : '🤍' }} {{ item.likes_count }}
            </button>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PetAvatar from '../components/pet/PetAvatar.vue'
import { useDiaryStore } from '../stores/diary'
import { useFeedStore } from '../stores/feed'
import { MOODS } from '../lib/constants'

const route = useRoute()
const router = useRouter()
const diaryStore = useDiaryStore()
const feedStore = useFeedStore()
const activeTab = computed(() => route.query.tab === 'square' ? 'square' : 'mine')

function switchTab(tab: 'mine' | 'square') {
  router.replace(tab === 'square' ? { query: { tab: 'square' } } : { query: {} })
}

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

watch(activeTab, tab => {
  if (tab === 'square') feedStore.fetchFeed()
}, { immediate: true })
</script>

<style scoped>
.diary-tabs {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  padding: 4px;
  margin-bottom: 16px;
  border-radius: var(--radius-md);
  background: #fff0f5;
}

.diary-tabs button {
  padding: 10px;
  border-radius: var(--radius-sm);
  color: var(--color-text-muted);
  background: transparent;
  font-weight: 600;
}

.diary-tabs button.active {
  color: var(--color-primary);
  background: white;
  box-shadow: 0 2px 8px rgb(0 0 0 / 6%);
}

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

.feed-list { display: flex; flex-direction: column; gap: 16px; }
.feed-card { padding: 16px; }
.feed-header { display: flex; align-items: center; gap: 10px; margin-bottom: 12px; }
.feed-info { display: flex; flex: 1; flex-direction: column; }
.feed-username { font-size: 0.9rem; font-weight: 600; }
.feed-pet-name { color: var(--color-text-muted); font-size: 0.75rem; }
.feed-title { margin-bottom: 6px; font-family: var(--font-body); font-size: 1rem; }
.feed-image { width: 100%; height: 160px; margin-top: 10px; border-radius: var(--radius-sm); object-fit: cover; }
.feed-actions { margin-top: 12px; padding-top: 10px; border-top: 1px solid var(--color-border); }
.like-btn { padding: 4px 12px; border-radius: var(--radius-full); background: none; font-size: 0.9rem; }
.like-btn.liked { background: #fff0f5; }
</style>
