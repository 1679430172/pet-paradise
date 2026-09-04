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

    <section class="password-card card">
      <div class="password-heading"><div><h3>修改密码</h3><p>修改后请使用新密码登录</p></div><span>账号安全</span></div>
      <form class="password-form" @submit.prevent="handleChangePassword">
        <label><span>当前密码</span><input v-model="currentPassword" class="form-input" type="password" autocomplete="current-password" placeholder="请输入当前密码" /></label>
        <label><span>新密码</span><input v-model="newPassword" class="form-input" type="password" autocomplete="new-password" minlength="4" placeholder="至少 4 位" /></label>
        <label><span>确认新密码</span><input v-model="confirmPassword" class="form-input" type="password" autocomplete="new-password" minlength="4" placeholder="再次输入新密码" /></label>
        <p v-if="passwordMessage" class="password-message" :class="{ error: passwordError }" role="status">{{ passwordMessage }}</p>
        <button class="btn btn-primary" type="submit" :disabled="changingPassword">{{ changingPassword ? '正在修改...' : '确认修改' }}</button>
      </form>
    </section>

    <button class="btn btn-secondary logout-btn" @click="handleLogout">退出登录</button>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { usePetStore } from '../stores/pet'
import { BADGES, PET_SPECIES_LABELS } from '../lib/constants'
import type { PetSpecies } from '../lib/constants'

const router = useRouter()
const authStore = useAuthStore()
const petStore = usePetStore()
const currentPassword = ref('')
const newPassword = ref('')
const confirmPassword = ref('')
const passwordMessage = ref('')
const passwordError = ref(false)
const changingPassword = ref(false)

function formatDate(dateStr: string) {
  const d = new Date(dateStr)
  return `${d.getFullYear()}/${d.getMonth() + 1}/${d.getDate()}`
}

async function handleLogout() {
  await authStore.signOut()
  router.push('/login')
}

async function handleChangePassword() {
  passwordMessage.value = ''
  passwordError.value = true
  if (!currentPassword.value) { passwordMessage.value = '请输入当前密码'; return }
  if (newPassword.value.length < 4) { passwordMessage.value = '新密码至少 4 位'; return }
  if (newPassword.value !== confirmPassword.value) { passwordMessage.value = '两次输入的新密码不一致'; return }
  if (newPassword.value === currentPassword.value) { passwordMessage.value = '新密码不能与当前密码相同'; return }
  changingPassword.value = true
  const { error } = await authStore.changeOwnPassword(currentPassword.value, newPassword.value)
  changingPassword.value = false
  if (error) { passwordMessage.value = error.message; return }
  currentPassword.value = ''
  newPassword.value = ''
  confirmPassword.value = ''
  passwordError.value = false
  passwordMessage.value = '密码修改成功'
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

.password-card { margin-bottom:20px; padding:20px; }
.password-heading { display:flex; align-items:flex-start; justify-content:space-between; gap:16px; margin-bottom:16px; }
.password-heading h3 { margin:0 0 3px; font-size:1rem; }
.password-heading p { margin:0; color:var(--color-text-muted); font-size:.72rem; }
.password-heading > span { padding:4px 9px; border-radius:999px; background:#edf5ef; color:#5f7d68; font-size:.66rem; }
.password-form { display:grid; gap:12px; }
.password-form label { display:grid; gap:6px; color:#666; font-size:.78rem; }
.password-form .btn { width:100%; padding:11px; }
.password-message { margin:0; color:#39734f; font-size:.76rem; }
.password-message.error { color:var(--color-danger,#c84e55); }
</style>
