<template>
  <div class="page profile-page">
    <h1 class="page-title">我的</h1>

    <div class="profile-card card">
      <div class="profile-avatar">
        {{ authStore.profile?.username?.charAt(0) || '?' }}
      </div>
      <h2 class="profile-name">{{ authStore.profile?.username }}</h2>
      <p class="profile-class">{{ authStore.profile?.class_name || '未设置班级' }}</p>
      <div class="profile-points">
        <span class="points-icon">⭐</span>
        <span class="points-value">{{ authStore.user?.points || 0 }}</span>
        <span class="points-label">积分</span>
      </div>
    </div>

    <!-- 徽章展示 -->
    <div class="badges-section" v-if="petStore.pet">
      <h3>我的徽章</h3>
      <div class="badges-grid">
        <div
          v-for="(badge, key) in BADGES"
          :key="key"
          class="badge-item"
          :class="{ unlocked: petStore.pet.badges?.includes(key as string) }"
        >
          <span class="badge-icon">{{ badge.icon }}</span>
          <span class="badge-name">{{ badge.name }}</span>
        </div>
      </div>
    </div>

    <!-- 宠物信息 -->
    <div class="pet-info card" v-if="petStore.pet">
      <h3>宠物信息</h3>
      <div class="info-row">
        <span>名字</span>
        <span>{{ petStore.pet.name }}</span>
      </div>
      <div class="info-row">
        <span>种类</span>
        <span>{{ PET_SPECIES_LABELS[petStore.pet.species as PetSpecies] }}</span>
      </div>
      <div class="info-row">
        <span>等级</span>
        <span>Lv.{{ petStore.pet.level }}</span>
      </div>
      <div class="info-row">
        <span>经验值</span>
        <span>{{ petStore.pet.xp }} XP</span>
      </div>
      <div class="info-row">
        <span>入园时间</span>
        <span>{{ formatDate(petStore.pet.created_at) }}</span>
      </div>
    </div>

    <button class="btn btn-secondary logout-btn" @click="handleLogout">退出登录</button>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { usePetStore } from '../stores/pet'
import { BADGES, PET_SPECIES_LABELS } from '../lib/constants'
import type { PetSpecies } from '../lib/constants'

const router = useRouter()
const authStore = useAuthStore()
const petStore = usePetStore()

function formatDate(dateStr: string) {
  const d = new Date(dateStr)
  return `${d.getFullYear()}/${d.getMonth() + 1}/${d.getDate()}`
}

async function handleLogout() {
  await authStore.signOut()
  router.push('/login')
}

onMounted(() => {
  if (!petStore.pet) {
    petStore.fetchPet()
  }
})
</script>

<style scoped>
.profile-card {
  text-align: center;
  padding: 28px;
  margin-bottom: 20px;
}

.profile-avatar {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  background: linear-gradient(135deg, var(--color-primary), var(--color-secondary));
  color: white;
  font-size: 1.8rem;
  font-weight: 600;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 12px;
}

.profile-name {
  font-size: 1.3rem;
  margin-bottom: 4px;
}

.profile-email {
  font-size: 0.8rem;
  color: var(--color-text-muted);
}

.profile-class {
  font-size: 0.8rem;
  color: var(--color-text-muted);
}

.profile-points {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin-top: 12px;
  background: linear-gradient(135deg, #FFF8E1, #FFECB3);
  padding: 8px 16px;
  border-radius: 20px;
}

.profile-points .points-icon {
  font-size: 1rem;
}

.profile-points .points-value {
  font-size: 1.2rem;
  font-weight: 700;
  color: #F57F17;
}

.profile-points .points-label {
  font-size: 0.8rem;
  color: #F9A825;
}

.badges-section {
  margin-bottom: 20px;
}

.badges-section h3 {
  font-size: 1rem;
  margin-bottom: 12px;
  color: var(--color-text);
}

.badges-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 10px;
}

.badge-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 12px 6px;
  background: white;
  border-radius: var(--radius-sm);
  border: 1px solid var(--color-border);
  opacity: 0.4;
  filter: grayscale(1);
}

.badge-item.unlocked {
  opacity: 1;
  filter: none;
  border-color: var(--color-primary-light);
}

.badge-icon {
  font-size: 1.5rem;
}

.badge-name {
  font-size: 0.65rem;
  color: var(--color-text-muted);
  text-align: center;
}

.pet-info {
  margin-bottom: 20px;
}

.pet-info h3 {
  font-size: 1rem;
  margin-bottom: 12px;
}

.info-row {
  display: flex;
  justify-content: space-between;
  padding: 8px 0;
  border-bottom: 1px solid var(--color-border);
  font-size: 0.85rem;
}

.info-row:last-child {
  border-bottom: none;
}

.info-row span:first-child {
  color: var(--color-text-muted);
}

.logout-btn {
  width: 100%;
  padding: 12px;
}
</style>
