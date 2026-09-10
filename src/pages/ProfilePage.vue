<template>
  <div class="page profile-page">
    <h1 class="page-title">我的</h1>

    <div class="profile-card card">
      <div class="profile-avatar">
        {{ authStore.profile?.username?.charAt(0) || '?' }}
      </div>
      <h2 class="profile-name">{{ authStore.profile?.username }}</h2>
      <p class="profile-class">{{ authStore.profile?.class_name || '未设置班级' }}</p>
      <div class="profile-wallet">
        <div class="profile-points">
          <span class="points-icon">⭐</span>
          <span class="points-value">{{ authStore.user?.points || 0 }}</span>
          <span class="points-label">积分</span>
        </div>
        <div v-if="authStore.hasFeature('travel')" class="wallet-chip ticket-chip"><span>🎫</span><strong>{{ travelStore.state?.tickets ?? '—' }}</strong><span>旅行券</span></div>
        <div v-if="authStore.hasFeature('travel')" class="wallet-chip stamp-chip"><span>✉</span><strong>{{ travelStore.state?.stamps ?? '—' }}</strong><span>印章</span></div>
      </div>
    </div>

    <!-- 徽章展示 -->
    <div class="badges-section card" v-if="petStore.currentPet">
      <div class="section-heading"><h3>我的徽章</h3><small>账号成就</small></div>
      <div class="badges-grid">
        <div
          v-for="(badge, key) in BADGES"
          :key="key"
          class="badge-item"
          :class="{ unlocked: accountBadges.includes(key as string) }"
        >
          <span class="badge-icon">{{ badge.icon }}</span>
          <span class="badge-name">{{ badge.name }}</span>
        </div>
      </div>
    </div>

    <!-- 宠物信息 -->
    <div class="pet-info card" v-if="petStore.currentPet">
      <div class="section-heading">
        <h3>宠物信息 <small>· {{ petStore.currentPet.name }}</small></h3>
        <div v-if="petStore.pets.length > 1" class="pet-tabs" aria-label="选择宠物">
          <button v-for="pet in petStore.pets" :key="pet.id" type="button" :class="{ active: pet.id === petStore.currentPet?.id }" @click="petStore.selectPet(pet.id)">{{ pet.name }}</button>
        </div>
      </div>
      <div class="info-row">
        <span>名字</span>
        <span>{{ petStore.currentPet.name }}</span>
      </div>
      <div class="info-row">
        <span>种类</span>
        <span>{{ PET_SPECIES_LABELS[petStore.currentPet.species as PetSpecies] }}</span>
      </div>
      <div class="info-row">
        <span>等级</span>
        <span>Lv.{{ petStore.currentPet.level }}</span>
      </div>
      <div class="info-row">
        <span>经验值</span>
        <span>{{ petStore.currentPet.xp }} XP</span>
      </div>
      <div class="info-row">
        <span>入园时间</span>
        <span>{{ formatDate(petStore.currentPet.created_at) }}</span>
      </div>
    </div>

    <section class="password-card card">
      <div class="password-heading">
        <div><h3>账号安全</h3><p>定期修改密码，保护你的宠物账号</p></div>
        <div class="account-actions">
          <button class="change-password-btn" type="button" @click="openPasswordDialog">修改密码</button>
          <button class="logout-link" type="button" @click="handleLogout">退出登录</button>
        </div>
      </div>
    </section>

    <Teleport to="body">
      <div v-if="showPasswordDialog" class="dialog-overlay" role="presentation" @click.self="closePasswordDialog" @keydown.esc="closePasswordDialog">
        <section class="password-dialog card" role="dialog" aria-modal="true" aria-labelledby="password-dialog-title">
          <header class="password-dialog-heading">
            <div>
              <span>账号安全</span>
              <h2 id="password-dialog-title">修改密码</h2>
              <p>修改成功后，请使用新密码重新登录</p>
            </div>
            <button class="dialog-close" type="button" aria-label="关闭修改密码弹窗" @click="closePasswordDialog">×</button>
          </header>
          <form class="password-form" @submit.prevent="handleChangePassword">
            <label><span>当前密码</span><input v-model="currentPassword" class="form-input" type="password" autocomplete="current-password" placeholder="请输入当前密码" autofocus /></label>
            <label><span>新密码</span><input v-model="newPassword" class="form-input" type="password" autocomplete="new-password" minlength="4" placeholder="至少 4 位" /></label>
            <label><span>确认新密码</span><input v-model="confirmPassword" class="form-input" type="password" autocomplete="new-password" minlength="4" placeholder="再次输入新密码" /></label>
            <p v-if="passwordMessage" class="password-message" :class="{ error: passwordError }" role="status">{{ passwordMessage }}</p>
            <div class="password-actions">
              <button class="btn btn-secondary" type="button" :disabled="changingPassword" @click="closePasswordDialog">取消</button>
              <button class="btn btn-primary" type="submit" :disabled="changingPassword">{{ changingPassword ? '正在修改...' : '确认修改' }}</button>
            </div>
          </form>
        </section>
      </div>
    </Teleport>

  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { usePetStore } from '../stores/pet'
import { useTravelStore } from '../stores/travel'
import { BADGES, PET_SPECIES_LABELS } from '../lib/constants'
import type { PetSpecies } from '../lib/constants'

const router = useRouter()
const authStore = useAuthStore()
const petStore = usePetStore()
const travelStore = useTravelStore()
const currentPassword = ref('')
const newPassword = ref('')
const confirmPassword = ref('')
const passwordMessage = ref('')
const passwordError = ref(false)
const changingPassword = ref(false)
const showPasswordDialog = ref(false)
const accountBadges = computed(() => Array.from(new Set([
  ...(authStore.user?.badges || []),
  ...petStore.pets.flatMap(pet => pet.badges || []),
])))

function formatDate(dateStr: string) {
  const d = new Date(dateStr)
  return `${d.getFullYear()}/${d.getMonth() + 1}/${d.getDate()}`
}

async function handleLogout() {
  await authStore.signOut()
  router.push('/login')
}

function resetPasswordForm() {
  currentPassword.value = ''
  newPassword.value = ''
  confirmPassword.value = ''
  passwordMessage.value = ''
  passwordError.value = false
}

function openPasswordDialog() {
  resetPasswordForm()
  showPasswordDialog.value = true
}

function closePasswordDialog() {
  if (changingPassword.value) return
  showPasswordDialog.value = false
  resetPasswordForm()
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

onMounted(async () => {
  if (petStore.pets.length === 0) await petStore.fetchPets()
  if (authStore.hasFeature('travel')) await travelStore.refresh().catch(() => undefined)
})
</script>

<style scoped>
.profile-card {
  text-align: center;
  padding: 20px;
  margin-bottom: 16px;
}

.profile-avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: linear-gradient(135deg, var(--color-primary), var(--color-secondary));
  color: white;
  font-size: 1.45rem;
  font-weight: 600;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 8px;
}

.profile-name {
  font-size: 1.18rem;
  margin-bottom: 2px;
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
  margin-top: 8px;
  background: linear-gradient(135deg, #FFF8E1, #FFECB3);
  padding: 6px 13px;
  border-radius: 20px;
}

.profile-points .points-icon {
  font-size: 1rem;
}

.profile-points .points-value {
  font-size: 1rem;
  font-weight: 700;
  color: #F57F17;
}

.profile-points .points-label {
  font-size: 0.8rem;
  color: #F9A825;
}

.profile-wallet { display:flex; align-items:center; justify-content:center; flex-wrap:wrap; gap:8px; }
.wallet-chip { display:inline-flex; align-items:center; gap:5px; padding:6px 11px; border-radius:20px; font-size:.76rem; }
.wallet-chip strong { font-size:.95rem; }
.ticket-chip { background:#eeedf9; color:#715d9d; }
.stamp-chip { background:#edf5ef; color:#52705c; }

.badges-section {
  margin-bottom: 16px;
  padding: 20px;
}

.badges-section h3 {
  font-size: 1rem;
  margin: 0;
  color: var(--color-text);
}

.section-heading { display:flex; align-items:center; justify-content:space-between; gap:12px; margin-bottom:12px; }
.section-heading > small,
.pet-info h3 small { color:var(--color-text-muted); font-size:.72rem; font-weight:500; }
.pet-tabs { display:flex; gap:6px; max-width:65%; overflow-x:auto; scrollbar-width:none; }
.pet-tabs::-webkit-scrollbar { display:none; }
.pet-tabs button { flex-shrink:0; padding:5px 9px; border:1px solid var(--color-border); border-radius:999px; background:white; color:var(--color-text-muted); font:inherit; font-size:.68rem; cursor:pointer; }
.pet-tabs button.active { border-color:var(--color-primary); background:#fff0f5; color:var(--color-primary); font-weight:700; }

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
  min-height: 64px;
  opacity: 0.6;
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
  margin-bottom: 16px;
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

.password-card { margin-bottom:16px; padding:18px 20px; }
.password-heading { display:flex; align-items:center; justify-content:space-between; gap:16px; }
.password-heading h3 { margin:0 0 3px; font-size:1rem; }
.password-heading p { margin:0; color:var(--color-text-muted); font-size:.72rem; }
.change-password-btn { flex-shrink:0; padding:9px 14px; border:1px solid var(--color-primary-light); border-radius:999px; background:#fff8fb; color:var(--color-primary); font:inherit; font-size:.78rem; font-weight:700; cursor:pointer; }
.change-password-btn:hover { background:#fff0f5; }
.account-actions { display:flex; align-items:center; gap:10px; flex-shrink:0; }
.logout-link { padding:9px 14px; border:1px solid rgba(202,85,103,.25); border-radius:999px; background:white; color:#b45868; font:inherit; font-size:.78rem; cursor:pointer; }
.logout-link:hover { border-color:rgba(202,85,103,.45); background:#fff8f8; }
.dialog-overlay { position:fixed; inset:0; z-index:300; display:grid; place-items:center; padding:20px; background:rgba(46,34,51,.48); backdrop-filter:blur(4px); }
.password-dialog { width:min(420px,100%); max-height:calc(100dvh - 40px); overflow-y:auto; padding:24px; }
.password-dialog-heading { display:flex; align-items:flex-start; justify-content:space-between; gap:18px; margin-bottom:20px; }
.password-dialog-heading span { color:var(--color-primary); font-size:.68rem; font-weight:800; letter-spacing:.1em; }
.password-dialog-heading h2 { margin:5px 0 5px; font-size:1.3rem; }
.password-dialog-heading p { margin:0; color:var(--color-text-muted); font-size:.76rem; }
.dialog-close { width:34px; height:34px; flex-shrink:0; border:0; border-radius:50%; background:#f6f1f3; color:#6f6268; font-size:1.35rem; line-height:1; cursor:pointer; }
.password-form { display:grid; gap:12px; }
.password-form label { display:grid; gap:6px; color:#666; font-size:.78rem; }
.password-actions { display:grid; grid-template-columns:1fr 1.6fr; gap:10px; margin-top:4px; }
.password-form .btn { width:100%; padding:11px; }
.password-message { margin:0; color:#39734f; font-size:.76rem; }
.password-message.error { color:var(--color-danger,#c84e55); }

@media (min-width: 768px) {
  .profile-card {
    display:grid;
    grid-template-columns:auto minmax(0,1fr) auto;
    grid-template-rows:auto auto;
    align-items:center;
    gap:2px 16px;
    padding:22px 26px;
    text-align:left;
  }
  .profile-avatar { grid-column:1; grid-row:1 / 3; margin:0; }
  .profile-name { grid-column:2; grid-row:1; align-self:end; }
  .profile-class { grid-column:2; grid-row:2; align-self:start; }
  .profile-wallet { grid-column:3; grid-row:1 / 3; justify-content:flex-end; margin:0; }
  .badges-section h3 { margin-top:0; }
  .badges-section { height:100%; box-sizing:border-box; }
  .badge-item { min-height:72px; }
  .pet-info { padding:20px; }
}

@media (max-width: 767px) {
  .badges-grid { grid-template-columns:repeat(3,1fr); gap:8px; }
  .badge-item { padding:10px 6px; }
}

@media (max-width: 420px) {
  .password-heading { align-items:flex-start; flex-direction:column; }
  .password-heading p { max-width:190px; }
  .account-actions { width:100%; }
  .account-actions button { flex:1; }
  .password-dialog { padding:20px; }
}
</style>
