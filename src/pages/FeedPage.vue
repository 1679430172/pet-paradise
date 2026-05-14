<template>
  <div class="page">
    <h1 class="page-title">班级广场</h1>

    <div v-if="feedStore.loading" class="loading">加载中...</div>

    <div v-else-if="feedStore.items.length === 0" class="empty">
      <span class="empty-icon">🌍</span>
      <p>还没有动态，快去写一篇公开日记吧！</p>
    </div>

    <div v-else class="feed-list">
      <div v-for="item in feedStore.items" :key="item.id" class="feed-card card">
        <div class="feed-header">
          <PetAvatar
            class="feed-pet-avatar"
            :species="item.pets?.species"
            :level="item.pets?.level || 1"
            :size="40"
          />
          <div class="feed-info">
            <span class="feed-username">{{ item.profiles?.username || '匿名' }}</span>
            <span class="feed-pet-name">{{ item.pets?.name }} · Lv.{{ item.pets?.level }}</span>
          </div>
          <span class="feed-date">{{ formatDate(item.created_at) }}</span>
        </div>

        <h3 class="feed-title">{{ getMoodIcon(item.mood) }} {{ item.title }}</h3>
        <p class="feed-content">{{ item.content.slice(0, 100) }}{{ item.content.length > 100 ? '...' : '' }}</p>
        <img v-if="item.image_url" :src="item.image_url" class="feed-image" alt="" />

        <div class="feed-actions">
          <button
            class="like-btn"
            :class="{ liked: item.liked_by_me }"
            @click="feedStore.toggleLike(item.id, item.owner_id)"
          >
            {{ item.liked_by_me ? '❤️' : '🤍' }} {{ item.likes_count }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useFeedStore } from '../stores/feed'
import { MOODS } from '../lib/constants'
import PetAvatar from '../components/pet/PetAvatar.vue'

const feedStore = useFeedStore()

function getMoodIcon(mood: string) {
  return MOODS.find(m => m.value === mood)?.icon ?? ''
}

function formatDate(dateStr: string) {
  const d = new Date(dateStr)
  return `${d.getMonth() + 1}/${d.getDate()}`
}

onMounted(() => {
  feedStore.fetchFeed()
})
</script>

<style scoped>
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

.feed-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.feed-card {
  padding: 16px;
}

.feed-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 12px;
}

.feed-pet-avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.2rem;
}

.feed-info {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.feed-username {
  font-size: 0.9rem;
  font-weight: 600;
}

.feed-pet-name {
  font-size: 0.75rem;
  color: var(--color-text-muted);
}

.feed-date {
  font-size: 0.75rem;
  color: var(--color-text-muted);
}

.feed-title {
  font-size: 1rem;
  font-family: var(--font-body);
  margin-bottom: 6px;
}

.feed-content {
  font-size: 0.85rem;
  color: var(--color-text-muted);
  line-height: 1.5;
}

.feed-image {
  width: 100%;
  height: 160px;
  object-fit: cover;
  border-radius: var(--radius-sm);
  margin-top: 10px;
}

.feed-actions {
  margin-top: 12px;
  padding-top: 10px;
  border-top: 1px solid var(--color-border);
}

.like-btn {
  background: none;
  font-size: 0.9rem;
  padding: 4px 12px;
  border-radius: var(--radius-full);
  transition: all 0.2s;
}

.like-btn.liked {
  background: #FFF0F5;
}
</style>
