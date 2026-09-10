<template>
  <div class="app-shell" :class="{ 'has-navigation': showStudentNav || showTeacherNav }">
    <router-view />
    <BottomNav v-if="showStudentNav" />
    <TeacherNav v-if="showTeacherNav" />
    <AnnouncementDialog />
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from './stores/auth'
import BottomNav from './components/common/BottomNav.vue'
import TeacherNav from './components/teacher/TeacherNav.vue'
import AnnouncementDialog from './components/common/AnnouncementDialog.vue'

const route = useRoute()
const authStore = useAuthStore()

const activityEvents: (keyof WindowEventMap)[] = ['pointerdown', 'keydown', 'touchstart', 'scroll']
const recordActivity = () => authStore.recordActivity()
const syncSession = (event: StorageEvent) => {
  if (event.key === 'pet_session_expires_at' || event.key === 'pet_user_id') authStore.syncSessionExpiry()
}
const recordVisibleActivity = () => { if (document.visibilityState === 'visible') authStore.recordActivity() }

onMounted(() => {
  activityEvents.forEach(event => window.addEventListener(event, recordActivity, { passive: true }))
  window.addEventListener('storage', syncSession)
  document.addEventListener('visibilitychange', recordVisibleActivity)
})
onBeforeUnmount(() => {
  activityEvents.forEach(event => window.removeEventListener(event, recordActivity))
  window.removeEventListener('storage', syncSession)
  document.removeEventListener('visibilitychange', recordVisibleActivity)
})

const hideNavRoutes = ['login', 'register', 'pet-create']

const showStudentNav = computed(() => {
  if (hideNavRoutes.includes(route.name as string) || (route.name === 'teacher-pets' && route.query.classroom === '1')) return false
  return authStore.user && !authStore.isTeacher
})

const showTeacherNav = computed(() => {
  if (hideNavRoutes.includes(route.name as string) || (route.name === 'teacher-pets' && route.query.classroom === '1')) return false
  return authStore.user && authStore.isTeacher
})
</script>
