<template>
  <div class="app-shell" :class="{ 'has-navigation': showStudentNav || showTeacherNav }">
    <router-view />
    <BottomNav v-if="showStudentNav" />
    <TeacherNav v-if="showTeacherNav" />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from './stores/auth'
import BottomNav from './components/common/BottomNav.vue'
import TeacherNav from './components/teacher/TeacherNav.vue'

const route = useRoute()
const authStore = useAuthStore()

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
