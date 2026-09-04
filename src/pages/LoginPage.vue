<template>
  <div class="auth-page">
    <div class="auth-header">
      <div class="auth-icon animate-bounce">🐾</div>
      <h1>宠物乐园</h1>
      <p>欢迎回来，登录查看你的宠物吧！</p>
    </div>

    <form class="auth-form card" @submit.prevent="handleSubmit">
      <div class="form-group">
        <label class="form-label">账号</label>
        <input
          v-model="username"
          type="text"
          class="form-input"
          placeholder="请输入账号名"
          required
        />
      </div>
      <div class="form-group">
        <label class="form-label">密码</label>
        <input
          v-model="password"
          type="password"
          class="form-input"
          placeholder="请输入密码"
          required
        />
      </div>
      <div class="form-group">
        <label for="login-class" class="form-label">班级（学生同名时选择）</label>
        <select id="login-class" v-model="teacherId" class="form-input" :disabled="classesLoading">
          <option value="">不选择班级</option>
          <option v-for="item in classes" :key="item.id" :value="item.id">{{ classLabel(item) }}</option>
        </select>
        <p class="class-hint">老师和管理员登录时不用选择。</p>
      </div>

      <p v-if="error" class="auth-error">{{ error }}</p>

      <button type="submit" class="btn btn-primary auth-btn" :disabled="loading">
        {{ loading ? '登录中...' : '登录' }}
      </button>

      <p v-if="registrationChecked && registrationEnabled" class="auth-switch">
        还没有账号？<router-link to="/register">去注册</router-link>
      </p>
      <p v-else-if="registrationChecked" class="auth-switch registration-closed">管理员已关闭账号注册</p>
    </form>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const username = ref('')
const password = ref('')
interface LoginClass { id: string; username: string; class_name: string | null }
const teacherId = ref('')
const classes = ref<LoginClass[]>([])
const classesLoading = ref(true)
const error = ref('')
const loading = ref(false)
const registrationEnabled = ref(false)
const registrationChecked = ref(false)

onMounted(async () => {
  const [registration, classResult] = await Promise.all([
    authStore.fetchRegistrationEnabled(),
    authStore.fetchRegistrationClasses(),
  ])
  registrationEnabled.value = registration.data
  registrationChecked.value = true
  classes.value = classResult.data || []
  classesLoading.value = false
})

function classLabel(item: LoginClass) {
  const name = item.class_name || '默认班级'
  const duplicated = classes.value.some(other => other.id !== item.id && (other.class_name || '默认班级') === name)
  return duplicated ? `${name}（${item.username}）` : name
}

async function handleSubmit() {
  error.value = ''
  loading.value = true
  const { error: err } = await authStore.signIn(username.value, password.value, teacherId.value || undefined)
  loading.value = false
  if (err) {
    error.value = err.message || '用户名或密码错误'
  } else {
    router.push(authStore.isAdmin ? '/admin' : authStore.isTeacher ? '/teacher' : '/')
  }
}
</script>

<style scoped>
.auth-page {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background: linear-gradient(180deg, #FFF0F5 0%, var(--color-bg) 100%);
}

.auth-header {
  text-align: center;
  margin-bottom: 32px;
}

.auth-icon {
  font-size: 4rem;
  margin-bottom: 12px;
}

.auth-header h1 {
  font-size: 2rem;
  color: var(--color-primary);
  margin-bottom: 8px;
}

.auth-header p {
  color: var(--color-text-muted);
  font-size: 0.9rem;
}

.auth-form {
  width: 100%;
  max-width: 380px;
}

.auth-btn {
  width: 100%;
  margin-top: 8px;
  padding: 14px;
  font-size: 1rem;
}

.auth-error {
  color: var(--color-danger);
  font-size: 0.85rem;
  text-align: center;
  margin-bottom: 8px;
}

.auth-switch {
  text-align: center;
  margin-top: 16px;
  font-size: 0.9rem;
  color: var(--color-text-muted);
}

.registration-closed { color: #999; }

.class-hint {
  margin-top: 6px;
  color: var(--color-text-muted);
  font-size: 0.78rem;
}
</style>
