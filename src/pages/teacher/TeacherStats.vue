<template>
  <div class="page teacher-page">
    <h1 class="page-title">排行榜</h1>

    <div v-if="teacherStore.loading" class="loading-state">加载中...</div>
    <div v-else class="leaderboard">
      <div
        v-for="(entry, index) in teacherStore.leaderboard"
        :key="entry.id"
        class="rank-item card"
      >
        <div class="rank-badge" :class="getRankClass(index)">{{ index + 1 }}</div>
        <div class="rank-info">
          <span class="rank-name">{{ entry.username }}</span>
          <span class="rank-pet">{{ entry.pet_name }} · Lv.{{ entry.pet_level }}</span>
        </div>
        <div class="rank-points">{{ entry.points }} <small>积分</small></div>
      </div>
      <div v-if="teacherStore.leaderboard.length === 0" class="empty-state">暂无学生数据</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useTeacherStore } from '../../stores/teacher'

const teacherStore = useTeacherStore()

onMounted(() => {
  teacherStore.fetchLeaderboard()
})

function getRankClass(index: number) {
  if (index === 0) return 'gold'
  if (index === 1) return 'silver'
  if (index === 2) return 'bronze'
  return ''
}
</script>

<style scoped>
.teacher-page {
  padding-bottom: 80px;
}

.loading-state, .empty-state {
  text-align: center;
  color: #999;
  padding: 32px;
}

.leaderboard {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.rank-item {
  display: flex;
  align-items: center;
  padding: 14px 16px;
  gap: 14px;
}

.rank-badge {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: #eee;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 0.85rem;
  color: #666;
  flex-shrink: 0;
}

.rank-badge.gold {
  background: linear-gradient(135deg, #FFD700, #FFA500);
  color: white;
}

.rank-badge.silver {
  background: linear-gradient(135deg, #C0C0C0, #A8A8A8);
  color: white;
}

.rank-badge.bronze {
  background: linear-gradient(135deg, #CD7F32, #B87333);
  color: white;
}

.rank-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.rank-name {
  font-weight: 600;
  font-size: 0.95rem;
}

.rank-pet {
  font-size: 0.8rem;
  color: #999;
}

.rank-points {
  font-weight: 700;
  color: var(--color-primary);
  font-size: 1.1rem;
}

.rank-points small {
  font-size: 0.7rem;
  font-weight: 400;
  color: #999;
}
</style>
