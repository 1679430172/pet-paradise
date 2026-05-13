<template>
  <nav class="teacher-nav">
    <router-link
      v-for="item in navItems"
      :key="item.route"
      :to="item.route"
      class="teacher-nav-item"
      :class="{ active: isActive(item.route) }"
    >
      <span class="nav-icon">{{ item.icon }}</span>
      <span class="nav-label">{{ item.label }}</span>
    </router-link>
  </nav>
</template>

<script setup lang="ts">
import { useRoute } from 'vue-router'

const route = useRoute()

const navItems = [
  { icon: '📊', label: '总览', route: '/teacher' },
  { icon: '👥', label: '学生', route: '/teacher/students' },
  { icon: '🐾', label: '宠物', route: '/teacher/pets' },
  { icon: '📋', label: '任务', route: '/teacher/tasks' },
  { icon: '🏆', label: '排行', route: '/teacher/stats' },
  { icon: '⚙️', label: '设置', route: '/teacher/settings' },
]

function isActive(path: string) {
  if (path === '/teacher') return route.path === '/teacher'
  return route.path.startsWith(path)
}
</script>

<style scoped>
.teacher-nav {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  display: flex;
  background: white;
  border-top: 1px solid #eee;
  padding: 8px 0;
  padding-bottom: env(safe-area-inset-bottom, 8px);
  z-index: 100;
  box-shadow: 0 -2px 12px rgba(0, 0, 0, 0.06);
}

.teacher-nav-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  text-decoration: none;
  color: #999;
  font-size: 0.72rem;
  transition: color 0.2s;
}

.teacher-nav-item.active {
  color: var(--color-primary);
}

.nav-icon {
  font-size: 1.3rem;
}

.nav-label {
  font-weight: 500;
}
</style>
