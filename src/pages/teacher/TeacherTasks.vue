<template>
  <div class="page teacher-page">
    <div class="page-header">
      <h1 class="page-title">任务管理</h1>
      <router-link to="/teacher/tasks/new" class="btn btn-primary btn-sm">+ 新建</router-link>
    </div>

    <div v-if="tasksStore.loading" class="loading-state">加载中...</div>
    <div v-else-if="tasksStore.tasks.length === 0" class="empty-state">暂无任务，点击"新建"创建</div>
    <div v-else class="task-list">
      <div v-for="task in tasksStore.tasks" :key="task.id" class="task-card card">
        <div class="task-info">
          <span class="task-name">{{ task.name }}</span>
          <span class="task-desc">{{ task.description || '无描述' }}</span>
        </div>
        <div class="task-right">
          <span class="task-points">+{{ task.points }}</span>
          <div class="task-actions">
            <router-link :to="`/teacher/tasks/${task.id}/edit`" class="action-btn">编辑</router-link>
            <button class="action-btn danger" @click="handleDelete(task.id)">删除</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useTasksStore } from '../../stores/tasks'

const tasksStore = useTasksStore()

onMounted(() => {
  tasksStore.fetchTasks()
})

async function handleDelete(id: string) {
  if (!confirm('确定删除此任务？')) return
  await tasksStore.deleteTask(id)
}
</script>

<style scoped>
.teacher-page {
  padding-bottom: 80px;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.btn-sm {
  padding: 8px 16px;
  font-size: 0.85rem;
  border-radius: 8px;
  text-decoration: none;
}

.loading-state, .empty-state {
  text-align: center;
  color: #999;
  padding: 32px;
}

.task-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.task-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 14px 16px;
}

.task-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
  flex: 1;
}

.task-name {
  font-weight: 600;
  font-size: 0.95rem;
}

.task-desc {
  font-size: 0.8rem;
  color: #999;
}

.task-right {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 6px;
}

.task-points {
  font-weight: 700;
  color: var(--color-success);
  font-size: 1rem;
}

.task-actions {
  display: flex;
  gap: 8px;
}

.action-btn {
  font-size: 0.75rem;
  color: var(--color-primary);
  text-decoration: none;
  cursor: pointer;
  background: none;
  border: none;
  padding: 0;
}

.action-btn.danger {
  color: var(--color-danger);
}
</style>
