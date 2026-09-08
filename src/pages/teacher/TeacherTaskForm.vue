<template>
  <div class="page teacher-page task-form-page">
    <div class="page-header">
      <button class="btn-back" @click="router.back()">← 返回</button>
      <h1 class="page-title">{{ isEdit ? '编辑任务' : '新建任务' }}</h1>
    </div>

    <form class="task-form card" @submit.prevent="handleSubmit">
      <div class="form-group">
        <label class="form-label">任务名称</label>
        <input
          v-model="name"
          type="text"
          class="form-input"
          placeholder="如：完成课堂练习"
          required
        />
      </div>
      <div class="form-group">
        <label class="form-label">任务描述</label>
        <textarea
          v-model="description"
          class="form-input"
          placeholder="描述任务内容（选填）"
          rows="3"
        ></textarea>
      </div>
      <div class="form-group">
        <label class="form-label">奖励积分</label>
        <input
          v-model.number="points"
          type="number"
          class="form-input"
          placeholder="如：10"
          min="0"
          max="100"
          required
        />
      </div>

      <div v-if="authStore.hasFeature('travel')" class="form-group">
        <label class="form-label" for="task-travel-tickets">奖励旅行券</label>
        <input id="task-travel-tickets" v-model.number="travelTickets" type="number" class="form-input" min="0" max="100" step="1" required />
        <small>每次完成发放的张数。积分与旅行券可任选一种，也可同时奖励；每张券可出发一次。</small>
      </div>
      <p v-if="error" class="form-error">{{ error }}</p>

      <button type="submit" class="btn btn-primary form-btn" :disabled="loading">
        {{ loading ? '保存中...' : '保存' }}
      </button>
    </form>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useTasksStore } from '../../stores/tasks'
import { useAuthStore } from '../../stores/auth'

const route = useRoute()
const router = useRouter()
const tasksStore = useTasksStore()
const authStore = useAuthStore()

const isEdit = computed(() => !!route.params.id)
const name = ref('')
const description = ref('')
const points = ref(10)
const travelTickets = ref(0)
const error = ref('')
const loading = ref(false)

onMounted(async () => {
  if (isEdit.value) {
    await tasksStore.fetchAllTasks()
    const task = tasksStore.tasks.find(t => t.id === route.params.id)
    if (task) {
      name.value = task.name
      description.value = task.description || ''
      points.value = task.points
      travelTickets.value = task.travel_tickets || 0
    }
  }
})

async function handleSubmit() {
  error.value = ''
  if (![points.value, travelTickets.value].every(n => Number.isInteger(n) && n >= 0 && n <= 100) || points.value + travelTickets.value === 0) {
    error.value = '积分和旅行券需为 0～100 的整数，且至少设置一项奖励'
    return
  }
  loading.value = true

  if (isEdit.value) {
    const { error: err } = await tasksStore.updateTask(route.params.id as string, {
      name: name.value,
      description: description.value,
      points: points.value,
      travel_tickets: travelTickets.value,
    })
    loading.value = false
    if (err) {
      error.value = err.message || '保存失败'
    } else {
      router.push('/teacher/tasks')
    }
  } else {
    const { error: err } = await tasksStore.createTask(name.value, description.value, points.value, travelTickets.value)
    loading.value = false
    if (err) {
      error.value = err.message || '创建失败'
    } else {
      router.push('/teacher/tasks')
    }
  }
}
</script>

<style scoped>
.teacher-page {
  padding-bottom: 80px;
}

.page-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 20px;
}

.btn-back {
  background: none;
  border: none;
  color: var(--color-primary);
  font-size: 0.9rem;
  cursor: pointer;
}

.task-form {
  padding: 20px;
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

textarea.form-input {
  resize: vertical;
  min-height: 60px;
}

.form-error {
  color: var(--color-danger);
  font-size: 0.85rem;
  text-align: center;
  margin-bottom: 8px;
}

.form-btn {
  width: 100%;
  padding: 12px;
  font-size: 1rem;
}
</style>
