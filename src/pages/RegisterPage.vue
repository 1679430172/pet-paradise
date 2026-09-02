<template>
  <div class="auth-page">
    <div class="auth-header">
      <div class="auth-icon animate-bounce">🐣</div>
      <h1>加入乐园</h1>
      <p>注册一个账号，创建你的专属宠物！</p>
    </div>

    <form class="auth-form card" @submit.prevent="handleSubmit">
      <div class="form-group">
        <label class="form-label">用户名</label>
        <input
          v-model="username"
          type="text"
          class="form-input"
          placeholder="2-12个字符"
          minlength="2"
          maxlength="12"
          required
        />
      </div>
      <div class="form-group">
        <label class="form-label">密码</label>
        <input
          v-model="password"
          type="password"
          class="form-input"
          placeholder="至少 4 位密码"
          minlength="4"
          required
        />
      </div>
      <div class="form-group">
        <label class="form-label">确认密码</label>
        <input
          v-model="confirmPassword"
          type="password"
          class="form-input"
          placeholder="再次输入密码"
          minlength="4"
          required
        />
      </div>
      <div class="form-group">
        <label for="registration-class" class="form-label">选择班级</label>
        <select
          id="registration-class"
          v-model="teacherId"
          class="form-input"
          :disabled="classesLoading || loading || classes.length === 0"
          required
        >
          <option disabled value="">{{ classesLoading ? '正在加载班级...' : '请选择所在班级' }}</option>
          <option v-for="item in classes" :key="item.id" :value="item.id">
            {{ classLabel(item) }}
          </option>
        </select>
        <p v-if="classesError" class="class-hint">
          {{ classesError }} <button type="button" class="retry-classes" @click="loadClasses">重新加载</button>
        </p>
        <p v-else-if="!classesLoading && classes.length === 0" class="class-hint">暂无可选班级，请联系老师创建班级。</p>
      </div>
      <p v-if="error" class="auth-error">{{ error }}</p>
      <p v-if="success" class="auth-success">{{ success }}</p>

      <button type="submit" class="btn btn-primary auth-btn" :disabled="loading || classesLoading || !teacherId || !!classesError">
        {{ loading ? '注册中...' : '注册' }}
      </button>

      <p class="auth-switch">
        已有账号？<router-link to="/login">去登录</router-link>
      </p>
    </form>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const username = ref('')
const password = ref('')
const confirmPassword = ref('')
interface RegistrationClass { id: string; username: string; class_name: string | null }
const teacherId = ref('')
const classes = ref<RegistrationClass[]>([])
const classesLoading = ref(true)
const classesError = ref('')
const error = ref('')
const success = ref('')
const loading = ref(false)

onMounted(loadClasses)

function classLabel(item: RegistrationClass) {
  const name = item.class_name || '默认班级'
  const duplicated = classes.value.some(other => other.id !== item.id && (other.class_name || '默认班级') === name)
  return duplicated ? `${name}（${item.username}）` : name
}

async function loadClasses() {
  classesLoading.value = true
  classesError.value = ''
  try {
    const { data, error: fetchError } = await authStore.fetchRegistrationClasses()
    if (fetchError) throw fetchError
    classes.value = data || []
    if (!classes.value.some(item => item.id === teacherId.value)) teacherId.value = ''
  } catch {
    classes.value = []
    teacherId.value = ''
    classesError.value = '班级加载失败，请重试。'
  } finally {
    classesLoading.value = false
  }
}

async function handleSubmit() {
  if (loading.value || classesLoading.value) return
  error.value = ''
  success.value = ''

  if (username.value.length < 2 || username.value.length > 12) {
    error.value = '用户名需要 2-12 个字符'
    return
  }
  if (password.value.length < 4) {
    error.value = '密码至少 4 位'
    return
  }
  if (password.value !== confirmPassword.value) {
    error.value = '两次密码输入不一致'
    return
  }

  if (!classes.value.some(item => item.id === teacherId.value)) {
    error.value = '请选择所在班级'
    return
  }

  loading.value = true
  const { error: err } = await authStore.signUp(username.value, password.value, teacherId.value)
  loading.value = false

  if (err) {
    error.value = err.message || '注册失败，请重试'
  } else {
    success.value = '注册成功！正在跳转...'
    setTimeout(() => router.push('/'), 1000)
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
  background: linear-gradient(180deg, #F0F8FF 0%, var(--color-bg) 100%);
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
  color: var(--color-secondary);
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

.class-hint {
  margin-top: 6px;
  font-size: .8rem;
  color: var(--color-text-muted);
}

.retry-classes {
  border: 0;
  background: none;
  color: var(--color-primary);
  cursor: pointer;
  font: inherit;
  text-decoration: underline;
}

.auth-error {
  color: var(--color-danger);
  font-size: 0.85rem;
  text-align: center;
  margin-bottom: 8px;
}

.auth-success {
  color: var(--color-success);
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
</style>
