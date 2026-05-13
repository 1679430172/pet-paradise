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

      <p v-if="error" class="auth-error">{{ error }}</p>
      <p v-if="success" class="auth-success">{{ success }}</p>

      <button type="submit" class="btn btn-primary auth-btn" :disabled="loading">
        {{ loading ? '注册中...' : '注册' }}
      </button>

      <p class="auth-switch">
        已有账号？<router-link to="/login">去登录</router-link>
      </p>
    </form>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const username = ref('')
const password = ref('')
const confirmPassword = ref('')
const error = ref('')
const success = ref('')
const loading = ref(false)

async function handleSubmit() {
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

  loading.value = true
  const { error: err } = await authStore.signUp(username.value, password.value)
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
