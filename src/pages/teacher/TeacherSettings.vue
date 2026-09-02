<template>
  <div class="page teacher-page settings-page">
    <h1 class="page-title">积分设置</h1>

    <div class="settings-card card">
      <h3>班级信息</h3>
      <p class="settings-desc">学生通过您的老师账号注册后，会自动加入这个班级。</p>
      <div class="form-group">
        <label class="form-label">班级名称</label>
        <input v-model="className" class="form-input" maxlength="30" placeholder="例如：向日葵一班" />
      </div>
      <div class="teacher-code">老师账号：<strong>{{ authStore.user?.username }}</strong></div>
      <button class="btn btn-primary form-btn" :disabled="loading" @click="handleSaveClass">保存班级信息</button>
    </div>

    <div v-if="authStore.isAdmin" class="settings-card card admin-card">
      <div class="admin-heading">
        <div>
          <h3>添加老师账号</h3>
          <p class="settings-desc">创建后，老师可以使用账号登录并管理自己的班级和学生。</p>
        </div>
        <span class="admin-badge">管理员</span>
      </div>
      <div class="form-group">
        <label class="form-label">老师账号</label>
        <input v-model="teacherForm.username" class="form-input" maxlength="20" autocomplete="off" placeholder="例如：teacher_wang" />
      </div>
      <div class="form-group">
        <label class="form-label">初始密码</label>
        <input v-model="teacherForm.password" type="password" class="form-input" minlength="6" autocomplete="new-password" placeholder="至少 6 位" />
      </div>
      <div class="form-group">
        <label class="form-label">班级名称</label>
        <input v-model="teacherForm.className" class="form-input" maxlength="30" placeholder="例如：彩虹二班" />
      </div>
      <p v-if="teacherError" class="inline-error">{{ teacherError }}</p>
      <p v-if="teacherSuccess" class="inline-success">{{ teacherSuccess }}</p>
      <button class="btn btn-primary form-btn" :disabled="creatingTeacher" @click="handleCreateTeacher">
        {{ creatingTeacher ? '创建中...' : '创建老师账号' }}
      </button>
    </div>

    <div class="settings-card card">
      <h3>宠物喂食积分消耗</h3>
      <p class="settings-desc">设置三档喂食所需的积分（统一作用于饱食度，档位越高恢复越多、获得经验越多）</p>

      <div class="form-group">
        <label class="form-label">🍖 普通粮消耗（hunger +20，xp +5）</label>
        <input v-model.number="costs.basic" type="number" class="form-input" min="0" max="100" />
      </div>
      <div class="form-group">
        <label class="form-label">🍗 营养粮消耗（hunger +50，xp +12）</label>
        <input v-model.number="costs.nice" type="number" class="form-input" min="0" max="100" />
      </div>
      <div class="form-group">
        <label class="form-label">🥩 豪华粮消耗（hunger +100，xp +25）</label>
        <input v-model.number="costs.luxury" type="number" class="form-input" min="0" max="100" />
      </div>

      <button class="btn btn-primary form-btn" :disabled="loading" @click="handleSaveCosts">
        {{ loading ? '保存中...' : '保存消耗设置' }}
      </button>
    </div>

    <div class="settings-card card">
      <h3>日记积分奖励</h3>
      <p class="settings-desc">学生每天写第一篇日记时自动获得的积分（后续不加分）</p>

      <div class="form-group">
        <label class="form-label">📖 每日首篇日记奖励</label>
        <input v-model.number="diaryPts" type="number" class="form-input" min="0" max="100" />
      </div>

      <button class="btn btn-primary form-btn" :disabled="loading" @click="handleSaveDiary">
        {{ loading ? '保存中...' : '保存日记设置' }}
      </button>
    </div>

    <p v-if="error" class="form-error">{{ error }}</p>
    <p v-if="success" class="form-success">{{ success }}</p>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { usePointsStore } from '../../stores/points'
import { useAuthStore } from '../../stores/auth'

const pointsStore = usePointsStore()
const authStore = useAuthStore()

const costs = reactive({ basic: 3, nice: 8, luxury: 15 })
const diaryPts = ref(5)
const loading = ref(false)
const error = ref('')
const success = ref('')
const className = ref('')
const creatingTeacher = ref(false)
const teacherError = ref('')
const teacherSuccess = ref('')
const teacherForm = reactive({ username: '', password: '', className: '' })

onMounted(async () => {
  className.value = authStore.user?.class_name || '默认班级'
  await Promise.all([
    pointsStore.fetchActionCosts(),
    pointsStore.fetchDiaryPoints(),
  ])
  costs.basic = pointsStore.actionCosts.basic
  costs.nice = pointsStore.actionCosts.nice
  costs.luxury = pointsStore.actionCosts.luxury
  diaryPts.value = pointsStore.diaryPoints
})

async function handleSaveClass() {
  error.value = ''
  success.value = ''
  loading.value = true
  const { error: err } = await authStore.updateClassName(className.value)
  loading.value = false
  if (err) error.value = err.message
  else success.value = '班级信息已保存，新注册学生会自动加入该班级'
}

async function handleCreateTeacher() {
  teacherError.value = ''
  teacherSuccess.value = ''
  creatingTeacher.value = true
  const { data, error: err } = await authStore.createTeacher(
    teacherForm.username,
    teacherForm.password,
    teacherForm.className,
  )
  creatingTeacher.value = false
  if (err) {
    teacherError.value = err.message || '创建失败，请重试'
    return
  }
  teacherSuccess.value = `老师「${data?.username}」创建成功，所属班级：${data?.class_name}`
  teacherForm.username = ''
  teacherForm.password = ''
  teacherForm.className = ''
}

async function handleSaveCosts() {
  error.value = ''
  success.value = ''
  loading.value = true
  const { error: err } = await pointsStore.updateActionCosts({ ...costs })
  loading.value = false
  if (err) {
    error.value = '保存失败，请重试'
  } else {
    success.value = '消耗设置已保存'
    setTimeout(() => { success.value = '' }, 2000)
  }
}

async function handleSaveDiary() {
  error.value = ''
  success.value = ''
  loading.value = true
  const { error: err } = await pointsStore.updateDiaryPoints(diaryPts.value)
  loading.value = false
  if (err) {
    error.value = '保存失败，请重试'
  } else {
    success.value = '日记设置已保存'
    setTimeout(() => { success.value = '' }, 2000)
  }
}
</script>

<style scoped>
.teacher-page {
  padding-bottom: 80px;
}

.settings-card {
  padding: 20px;
}

.settings-card h3 {
  font-size: 1rem;
  margin-bottom: 4px;
}

.settings-desc {
  color: #999;
  font-size: 0.8rem;
  margin-bottom: 20px;
}

.teacher-code {
  margin: -4px 0 12px;
  color: var(--color-text-muted);
  font-size: 0.85rem;
}

.admin-card {
  border: 1px solid rgba(139, 92, 246, 0.2);
  background: linear-gradient(145deg, #fff 0%, #faf7ff 100%);
}

.admin-heading {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
}

.admin-heading .settings-desc {
  margin-bottom: 20px;
}

.admin-badge {
  flex-shrink: 0;
  padding: 4px 9px;
  border-radius: 999px;
  background: #ede9fe;
  color: #7c3aed;
  font-size: 0.72rem;
  font-weight: 700;
}

.inline-error,
.inline-success {
  margin: -4px 0 6px;
  font-size: 0.82rem;
}

.inline-error { color: var(--color-danger); }
.inline-success { color: var(--color-success); }

.form-group {
  margin-bottom: 16px;
}

.form-label {
  display: block;
  margin-bottom: 6px;
  font-weight: 500;
  font-size: 0.9rem;
}

.form-error {
  color: var(--color-danger);
  font-size: 0.85rem;
  text-align: center;
  margin-bottom: 8px;
}

.form-success {
  color: var(--color-success);
  font-size: 0.85rem;
  text-align: center;
  margin-bottom: 8px;
}

.form-btn {
  width: 100%;
  padding: 12px;
  font-size: 1rem;
  margin-top: 8px;
}
</style>
