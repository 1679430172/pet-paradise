<template>
  <div class="page teacher-page stats-page">
    <div class="ranking-heading"><div><h1 class="page-title">本周成长榜</h1>
      <p class="ranking-note">{{ weekLabel }} · 北京时间</p></div>
      <button class="btn btn-secondary" :disabled="teacherStore.leaderboardLoading" @click="teacherStore.fetchLeaderboard()">刷新</button>
    </div>
    <p class="ranking-rule">按本周获得的任务与日记奖励积分排名，喂食消费不影响排名。同分并列，每周一重新统计。</p>
    <div v-if="teacherStore.leaderboardError" role="alert" class="ranking-error">{{ teacherStore.leaderboardError }}</div>
    <div v-else-if="teacherStore.leaderboardLoading" class="loading-state">正在统计本周成长...</div>
    <div v-else>
      <section v-for="group in rankingGroups" :key="group.title" class="ranking-section">
      <div class="section-heading"><h2>{{ group.title }}</h2><span>{{ group.honor ? '每一份努力，都值得闪耀' : '一起积累，继续成长' }}</span></div>
      <div class="leaderboard" :class="{ 'honor-board': group.honor }">
      <div v-for="lane in (group.honor ? podiumLanes : [{ rank: null, entries: group.entries }])" :key="lane.rank ?? 'all'" :class="group.honor ? ['podium-lane', getRankClass(lane.rank)] : 'rank-list-content'">
      <div v-for="entry in lane.entries" :key="entry.id" class="rank-item card" :class="getRankClass(entry.rank)">
        <div v-if="group.honor" class="podium-pet">
          <svg class="champion-crown" viewBox="0 0 64 44" aria-hidden="true">
            <path d="M8 12 20 23 32 5 44 23 56 12 51 35H13Z" fill="var(--stage-light)" stroke="var(--stage-deep)" stroke-width="2" stroke-linejoin="round" />
            <path d="M14 39H50" stroke="var(--stage-deep)" stroke-width="5" stroke-linecap="round" />
            <circle cx="32" cy="27" r="4" fill="var(--stage-pale)" />
          </svg>
          <span class="pet-sparkle sparkle-left" aria-hidden="true">✦</span>
          <span class="pet-sparkle sparkle-right" aria-hidden="true">✧</span>
          <PetAvatar v-if="entry.pet_species || !entry.pet_level" :species="entry.pet_species" :level="entry.pet_level || 1" :size="144" :empty="!entry.pet_level" :show-stage="!!entry.pet_species" />
          <span v-else class="pet-data-hint">宠物形象待加载<br>请点击刷新</span>
        </div>
        <div class="rank-badge" :class="getRankClass(entry.rank)" :aria-label="entry.rank ? `第 ${entry.rank} 名` : '暂无排名'">
          <span v-if="group.honor" class="medal" aria-hidden="true">{{ entry.rank === 1 ? '🥇' : entry.rank === 2 ? '🥈' : '🥉' }}</span>
          <template v-else>{{ entry.rank ?? '—' }}</template>
        </div>
        <div class="rank-info"><span class="rank-name">{{ entry.username }}</span>
          <span v-if="group.honor" class="honor-label">{{ entry.rank === 1 ? '第一名 · 闪耀之星' : entry.rank === 2 ? '第二名 · 成长之星' : '第三名 · 活力之星' }}</span>
          <span class="rank-pet">{{ entry.pet_name }}<template v-if="entry.pet_level"> · Lv.{{ entry.pet_level }}</template></span>
        </div>
        <div class="rank-points">{{ entry.points }} <small>本周获得</small></div>
        <div v-if="group.honor" class="podium-plinth" aria-hidden="true"><span>{{ entry.rank === 1 ? '✦' : '✧' }}</span><strong>{{ entry.rank }}</strong><span>{{ entry.rank === 1 ? '✦' : '✧' }}</span></div>
      </div>
      </div>
      </div>
      </section>
      <div v-if="teacherStore.leaderboard.length === 0" class="empty-state">班级里还没有学生</div>
      <p v-else-if="teacherStore.leaderboard.every(entry => entry.points === 0)" class="empty-state">新的一周开始啦，完成任务就能点亮本周成长榜。</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useTeacherStore } from '../../stores/teacher'
import PetAvatar from '../../components/pet/PetAvatar.vue'
const teacherStore = useTeacherStore()
const podiumLanes = computed(() => [1, 2, 3].map(rank => ({
  rank, entries: teacherStore.leaderboard.filter(entry => entry.rank === rank),
})))
const rankingGroups = computed(() => [
  { title: '本周荣誉榜', honor: true, entries: teacherStore.leaderboard.filter(entry => entry.rank !== null && entry.rank <= 3) },
  { title: '班级成长足迹', honor: false, entries: teacherStore.leaderboard.filter(entry => entry.rank === null || entry.rank > 3) },
].filter(group => group.entries.length > 0))
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

.ranking-section { margin-bottom: 28px; }
.section-heading { display: flex; flex-wrap: wrap; align-items: baseline; gap: 12px; margin-bottom: 14px; }
.section-heading h2 { font-size: 1rem; color: #4c5149; margin: 0; }
.section-heading > span { font-size: .76rem; color: #9a958b; }
:global(#app .app-shell .stats-page .leaderboard) { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 280px), 1fr)); gap: 14px; }
:global(#app .app-shell .stats-page .honor-board) { grid-template-columns: repeat(3, minmax(0, 1fr)); align-items: stretch; }
.rank-item { border: 1px solid #ece8e0; box-shadow: 0 3px 12px #534b3705; border-radius: 16px; min-height: 86px; }
.rank-points { white-space: nowrap; font-variant-numeric: tabular-nums; }
.rank-points small { display: block; text-align: right; margin-top: 4px; }
:global(#app .app-shell .stats-page .honor-board .rank-item) { position: relative; overflow: hidden; display: flex; flex-direction: column; justify-content: center; gap: 14px; padding: 28px 16px 24px; text-align: center; min-height: 275px; }
.honor-board .rank-item::after { content: '✧'; position: absolute; right: 18px; top: 12px; font-size: 50px; color: currentColor; opacity: .14; pointer-events: none; }
.honor-board .gold { background: linear-gradient(145deg, #fff9e6, #fff1c8); border-color: #eed395; color: #ab761b; box-shadow: 0 8px 24px #dca52214; }
.honor-board .silver { background: linear-gradient(145deg, #fafcff, #eaf0f8); border-color: #d6deeb; color: #667d9e; }
.honor-board .bronze { background: linear-gradient(145deg, #fff8f0, #fbe7d9); border-color: #efd0bb; color: #af7955; }
.honor-board .rank-badge { width: 68px; height: 68px; background: #ffffff99; border: 1px solid #ffffffc9; box-shadow: 0 5px 14px #735b1510; }
.medal { font-size: 44px; line-height: 1; filter: drop-shadow(0 3px 3px #8b66151a); }
.honor-board .rank-info { flex: none; gap: 7px; }
.honor-board .rank-name { font-size: 1.2rem; color: #444a43; }
.honor-label { font-size: .72rem; font-weight: 600; letter-spacing: .05em; }
.honor-board .rank-pet { color: #8e9089; font-size: .74rem; }
.honor-board .rank-points { font-size: 1.8rem; color: inherit; }
.honor-board .rank-points small { text-align: center; font-size: .7rem; color: #929084; }
@media (max-width: 640px) {
  :global(#app .app-shell .stats-page .honor-board) { grid-template-columns: 1fr; }
  :global(#app .app-shell .stats-page .honor-board .rank-item) { flex-direction: row; min-height: 130px; padding: 20px 16px; text-align: left; gap: 12px; }
  .honor-board .rank-info { flex: 1; }
  .honor-board .rank-badge { width: 54px; height: 54px; }
  .medal { font-size: 36px; }
  .honor-board .rank-name { font-size: 1rem; }
  .honor-board .rank-points { font-size: 1.5rem; }
  .honor-board .rank-item::after { font-size: 30px; top: 0; right: 6px; }
}

.rank-list-content { display: contents; }
:global(#app .app-shell .stats-page .honor-board) { align-items: start; padding-top: 8px; }
.podium-lane { display: flex; flex-direction: column; gap: 14px; min-width: 0; grid-row: 1; }
.honor-board > .podium-lane { background: none; border: none; box-shadow: none; }
.podium-lane.gold { grid-column: 2; }
.podium-lane.silver { grid-column: 1; padding-top: 32px; }
.podium-lane.bronze { grid-column: 3; padding-top: 56px; }
:global(#app .app-shell .stats-page .podium-lane.gold .rank-item) { min-height: 332px; border-bottom: 6px solid #dfb653; }
:global(#app .app-shell .stats-page .podium-lane.silver .rank-item) { min-height: 300px; border-bottom: 6px solid #a6b6ce; }
:global(#app .app-shell .stats-page .podium-lane.bronze .rank-item) { min-height: 276px; border-bottom: 6px solid #ce9670; }
@media (max-width: 640px) {
  .podium-lane.gold, .podium-lane.silver, .podium-lane.bronze { grid-column: 1; grid-row: auto; padding-top: 0; }
  .podium-lane:empty { display: none; }
  :global(#app .app-shell .stats-page .podium-lane:is(.gold, .silver, .bronze) .rank-item) { min-height: 130px; }
}

.podium-pet { display: flex; justify-content: center; align-items: center; width: 164px; height: 154px; border-radius: 50%; background: radial-gradient(ellipse, #fffdf6 20%, #ffffff55 60%, transparent 72%); }
.pet-data-hint { color: #8e9089; font-size: .8rem; line-height: 1.8; text-align: center; }
.honor-board .rank-item .rank-badge { position: absolute; top: 18px; left: 18px; width: 42px; height: 42px; }
.honor-board .rank-item .medal { font-size: 30px; }
:global(#app .app-shell .stats-page .podium-lane.gold .rank-item) { min-height: 432px; }
:global(#app .app-shell .stats-page .podium-lane.silver .rank-item) { min-height: 400px; }
:global(#app .app-shell .stats-page .podium-lane.bronze .rank-item) { min-height: 376px; }
@media (max-width: 640px) {
  :global(#app .app-shell .stats-page .podium-lane:is(.gold, .silver, .bronze) .rank-item) { min-height: 210px; flex-wrap: wrap; justify-content: flex-start; padding: 20px 16px; }
  .podium-pet { width: 100px; height: 110px; }
  .podium-pet :deep(.pet-avatar-wrap) { transform: scale(.75); }
  .honor-board .rank-item .rank-badge { top: 8px; left: 10px; width: 30px; height: 30px; z-index: 1; }
  .honor-board .rank-item .medal { font-size: 23px; }
  .honor-board .rank-points { width: 100%; text-align: center; }
}

/* Pet award stage: decorative layers stay behind the readable content. */
.honor-board .rank-item.gold { --stage-light: #f4c34f; --stage-deep: #bd8422; --stage-pale: #fff0ab; box-shadow: 0 12px 32px #d7a32924, inset 0 1px 0 #fff; }
.honor-board .rank-item.silver { --stage-light: #b3c8e2; --stage-deep: #758ba8; --stage-pale: #e9f3ff; }
.honor-board .rank-item.bronze { --stage-light: #e2ae88; --stage-deep: #a76c44; --stage-pale: #ffe5cc; }
:global(#app .app-shell .stats-page .honor-board .podium-lane .rank-item) { padding-bottom: 82px; }
:global(#app .app-shell .stats-page .podium-lane.gold .rank-item) { min-height: 492px; }
:global(#app .app-shell .stats-page .podium-lane.silver .rank-item) { min-height: 460px; }
:global(#app .app-shell .stats-page .podium-lane.bronze .rank-item) { min-height: 436px; }
.podium-pet { position: relative; isolation: isolate; margin-top: 18px; background: radial-gradient(ellipse, #ffffffed 0%, var(--stage-pale) 48%, transparent 72%); }
.podium-pet::before { content: ''; position: absolute; inset: 10px 0 0; border: 1px solid var(--stage-light); border-radius: 50%; opacity: .55; box-shadow: 0 0 24px var(--stage-pale), inset 0 0 18px #ffffffc0; z-index: -1; }
.podium-pet::after { content: ''; position: absolute; bottom: 0; left: 12%; right: 12%; height: 18px; border-radius: 50%; background: linear-gradient(#ffffffdf, var(--stage-light)); box-shadow: 0 5px 0 var(--stage-deep), 0 10px 16px #795a1720; z-index: -1; }
.champion-crown { position: absolute; width: 52px; height: 36px; top: -20px; left: calc(50% - 26px); z-index: 2; filter: drop-shadow(0 3px 5px #bc842644); animation: crown-float 6s ease-in-out infinite; pointer-events: none; }
.pet-sparkle { position: absolute; color: #d4a126; font-size: 22px; pointer-events: none; animation: award-glimmer 6s ease-in-out infinite; }
.sparkle-left { left: -10px; top: 32px; }
.sparkle-right { right: -8px; top: 70px; animation-delay: 3s; }
.podium-plinth { position: absolute; bottom: 0; left: 0; right: 0; height: 54px; display: flex; align-items: center; justify-content: center; gap: 28px; background: linear-gradient(115deg, var(--stage-light), var(--stage-pale) 48%, var(--stage-light)); color: var(--stage-deep); border-top: 5px solid #ffffffa6; box-shadow: inset 0 1px 0 var(--stage-light), inset 0 -8px 12px #6c51110a; }
.podium-plinth strong { font-size: 1.8rem; line-height: 1; text-shadow: 0 1px 0 #ffffffcc; }
.podium-plinth > span { font-size: 14px; opacity: .65; }
@keyframes crown-float { 0%, 100% { transform: translateY(0) rotate(-4deg); } 50% { transform: translateY(-5px) rotate(4deg); } }
@keyframes award-glimmer { 0%, 100% { opacity: .4; transform: scale(.85); } 50% { opacity: .9; transform: scale(1.05); } }
@media (prefers-reduced-motion: reduce) { .champion-crown, .pet-sparkle { animation: none; } }
@media (max-width: 640px) {
  :global(#app .app-shell .stats-page .honor-board .podium-lane:is(.gold, .silver, .bronze) .rank-item) { min-height: 270px; padding-bottom: 62px; }
  .podium-plinth { height: 42px; }
  .podium-plinth strong { font-size: 1.4rem; }
  .champion-crown { width: 42px; left: calc(50% - 21px); }
  .pet-sparkle { font-size: 16px; }
}
.honor-board .rank-item { animation: podium-arrive 1.4s cubic-bezier(.22, .7, .3, 1) both; }
.honor-board .rank-item.silver { animation-delay: .35s; }
.honor-board .rank-item.bronze { animation-delay: .7s; }
.pet-sparkle { color: var(--stage-deep); }
@keyframes podium-arrive {
  from { opacity: 0; transform: translateY(18px); }
  to { opacity: 1; transform: translateY(0); }
}
@media (prefers-reduced-motion: reduce) {
  .honor-board .rank-item { animation: none; }
}
</style>
