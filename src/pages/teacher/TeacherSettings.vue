<template>
  <div class="page teacher-page">
    <h1 class="page-title">积分设置</h1>

    <div class="settings-card card">
      <h3>宠物操作积分消耗</h3>
      <p class="settings-desc">设置学生进行宠物操作时需要消耗的积分数量</p>

      <div class="form-group">
        <label class="form-label">🍖 喂食消耗</label>
        <input v-model.number="costs.feed" type="number" class="form-input" min="0" max="100" />
      </div>
      <div class="form-group">
        <label class="form-label">🎾 玩耍消耗</label>
        <input v-model.number="costs.play" type="number" class="form-input" min="0" max="100" />
      </div>
      <div class="form-group">
        <label class="form-label">🛁 清洁消耗</label>
        <input v-model.number="costs.clean" type="number" class="form-input" min="0" max="100" />
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

const pointsStore = usePointsStore()

const costs = reactive({ feed: 5, play: 8, clean: 3 })
const diaryPts = ref(5)
const loading = ref(false)
const error = ref('')
const success = ref('')

onMounted(async () => {
  await Promise.all([
    pointsStore.fetchActionCosts(),
    pointsStore.fetchDiaryPoints(),
  ])
  costs.feed = pointsStore.actionCosts.feed
  costs.play = pointsStore.actionCosts.play
  costs.clean = pointsStore.actionCosts.clean
  diaryPts.value = pointsStore.diaryPoints
})

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
