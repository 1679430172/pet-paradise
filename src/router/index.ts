import { createRouter, createWebHashHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    // 公开页面
    {
      path: '/login',
      name: 'login',
      component: () => import('../pages/LoginPage.vue'),
      meta: { requiresAuth: false },
    },
    {
      path: '/register',
      name: 'register',
      component: () => import('../pages/RegisterPage.vue'),
      meta: { requiresAuth: false },
    },
    // 学生页面
    {
      path: '/',
      name: 'home',
      component: () => import('../pages/HomePage.vue'),
      meta: { requiresAuth: true, role: 'student' },
    },
    {
      path: '/pet/create',
      name: 'pet-create',
      component: () => import('../pages/PetCreatePage.vue'),
      meta: { requiresAuth: true, role: 'student' },
    },
    {
      path: '/diary',
      name: 'diary',
      component: () => import('../pages/DiaryPage.vue'),
      meta: { requiresAuth: true, role: 'student' },
    },
    {
      path: '/diary/new',
      name: 'diary-new',
      component: () => import('../pages/DiaryEditorPage.vue'),
      meta: { requiresAuth: true, role: 'student' },
    },
    {
      path: '/diary/:id',
      name: 'diary-detail',
      component: () => import('../pages/DiaryDetailPage.vue'),
      meta: { requiresAuth: true, role: 'student' },
    },
    {
      path: '/feed',
      name: 'feed',
      component: () => import('../pages/FeedPage.vue'),
      meta: { requiresAuth: true, role: 'student' },
    },
    {
      path: '/profile',
      name: 'profile',
      component: () => import('../pages/ProfilePage.vue'),
      meta: { requiresAuth: true, role: 'student' },
    },
    // 教师页面
    {
      path: '/teacher',
      name: 'teacher-dashboard',
      component: () => import('../pages/teacher/TeacherDashboard.vue'),
      meta: { requiresAuth: true, role: 'teacher' },
    },
    {
      path: '/teacher/students',
      name: 'teacher-students',
      component: () => import('../pages/teacher/TeacherStudents.vue'),
      meta: { requiresAuth: true, role: 'teacher' },
    },
    {
      path: '/teacher/students/:id',
      name: 'teacher-student-detail',
      component: () => import('../pages/teacher/TeacherStudentDetail.vue'),
      meta: { requiresAuth: true, role: 'teacher' },
    },
    {
      path: '/teacher/tasks',
      name: 'teacher-tasks',
      component: () => import('../pages/teacher/TeacherTasks.vue'),
      meta: { requiresAuth: true, role: 'teacher' },
    },
    {
      path: '/teacher/tasks/new',
      name: 'teacher-task-new',
      component: () => import('../pages/teacher/TeacherTaskForm.vue'),
      meta: { requiresAuth: true, role: 'teacher' },
    },
    {
      path: '/teacher/tasks/:id/edit',
      name: 'teacher-task-edit',
      component: () => import('../pages/teacher/TeacherTaskForm.vue'),
      meta: { requiresAuth: true, role: 'teacher' },
    },
    {
      path: '/teacher/pets',
      name: 'teacher-pets',
      component: () => import('../pages/teacher/TeacherPets.vue'),
      meta: { requiresAuth: true, role: 'teacher' },
    },
    {
      path: '/teacher/settings',
      name: 'teacher-settings',
      component: () => import('../pages/teacher/TeacherSettings.vue'),
      meta: { requiresAuth: true, role: 'teacher' },
    },
    {
      path: '/teacher/stats',
      name: 'teacher-stats',
      component: () => import('../pages/teacher/TeacherStats.vue'),
      meta: { requiresAuth: true, role: 'teacher' },
    },
  ],
})

router.beforeEach(async (to) => {
  const authStore = useAuthStore()

  if (!authStore.initialized) {
    await authStore.init()
  }

  // 未登录访问需要认证的页面 → 去登录
  if (to.meta.requiresAuth && !authStore.user) {
    return { name: 'login' }
  }

  // 已登录访问公开页面 → 根据角色跳转
  if (!to.meta.requiresAuth && authStore.user) {
    return authStore.isTeacher ? { name: 'teacher-dashboard' } : { name: 'home' }
  }

  // 角色权限检查
  if (to.meta.role && authStore.user) {
    if (to.meta.role === 'teacher' && !authStore.isTeacher) {
      return { name: 'home' }
    }
    if (to.meta.role === 'student' && authStore.isTeacher) {
      return { name: 'teacher-dashboard' }
    }
  }
})

export default router
