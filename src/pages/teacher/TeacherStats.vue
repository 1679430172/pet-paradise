<template>
  <div class="page teacher-page stats-page">
    <div class="ranking-heading"><div><h1 class="page-title">本周成长榜</h1>
      <p class="ranking-note">{{ weekLabel }} · 北京时间</p></div>
      <button class="btn btn-secondary" :disabled="teacherStore.leaderboardLoading" @click="teacherStore.fetchLeaderboard()">刷新</button>
    </div>
    <p class="ranking-rule">按本周获得的任务与日记奖励积分排名，喂食消费不影响排名。同分并列，每周一重新统计。</p>
    <div v-if="teacherStore.leaderboardError" role="alert" class="ranking-error">{{ teacherStore.leaderboardError }}</div>
    <div v-else-if="teacherStore.leaderboardLoading" class="loading-state">正在统计本周成长...</div>
    <div v-else class="leaderboard">
      <div v-for="entry in teacherStore.leaderboard" :key="entry.id" class="rank-item card">
        <div class="rank-badge" :class="getRankClass(entry.rank)">{{ entry.rank ?? '—' }}</div>
        <div class="rank-info"><span class="rank-name">{{ entry.username }}</span>
          <span class="rank-pet">{{ entry.pet_name }}<template v-if="entry.pet_level"> · Lv.{{ entry.pet_level }}</template></span>
        </div>
        <div class="rank-points">{{ entry.points }} <small>本周获得</small></div>
      </div>
      <div v-if="teacherStore.leaderboard.length === 0" class="empty-state">班级里还没有学生</div>
      <p v-else-if="teacherStore.leaderboard.every(entry => entry.points === 0)" class="empty-state">新的一周开始啦，完成任务就能点亮本周成长榜。</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useTeacherStore } from '../../stores/teacher'
const teacherStore = useTeacherStore()
const weekLabel = computed(() => {
  const { start, end } = teacherStore.leaderboardWeek
  if (!start || !end) return '本周'
  const format = (date: Date) => date.toLocaleDateString('zh-CN', { timeZone: 'Asia/Shanghai', month: 'numeric', day: 'numeric' })
  return `${format(new Date(start))} — ${format(new Date(new Date(end).getTime() - 1))}`
})
onMounted(() => teacherStore.fetchLeaderboard())
function getRankClass(rank: number | null) {
  return rank === 1 ? 'gold' : rank === 2 ? 'silver' : rank === 3 ? 'bronze' : ''
}
</script>

<style scoped>
.ranking-heading { display: flex; justify-content: space-between; align-items: center; gap: 16px; }
.ranking-heading .page-title { margin-bottom: 6px; }
.ranking-note, .ranking-rule { color: #666; line-height: 1.7; }
.ranking-rule { margin: 20px 0; padding: 16px; background: #fff7e7; border-radius: 14px; }
.ranking-error { padding: 20px; color: #aa2841; background: #fff0f3; border-radius: 12px; }

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
