<template>
  <div class="admin-page">
    <header class="admin-header">
      <div>
        <span class="eyebrow">管理员控制台</span>
        <h1>班级与老师</h1>
        <p>管理员只管理班级和老师账号，不参与学生日常管理。</p>
      </div>
      <button class="logout-btn" @click="handleLogout">退出登录</button>
    </header>

    <section class="create-card card">
      <div class="section-title">
        <div>
          <h2>添加老师</h2>
          <p>每位老师对应一个独立班级，学生注册时填写老师账号加入班级。</p>
        </div>
        <span class="admin-badge">ADMIN</span>
      </div>
      <div class="form-grid">
        <label>
          <span>老师账号</span>
          <input v-model="form.username" class="form-input" maxlength="20" autocomplete="off" placeholder="例如：teacher_wang" />
        </label>
        <label>
          <span>初始密码</span>
          <input v-model="form.password" type="password" class="form-input" minlength="6" autocomplete="new-password" placeholder="至少 6 位" />
        </label>
        <label>
          <span>班级名称</span>
          <input v-model="form.className" class="form-input" maxlength="30" placeholder="例如：彩虹二班" />
        </label>
      </div>
      <p v-if="error" class="message error">{{ error }}</p>
      <p v-if="success" class="message success">{{ success }}</p>
      <button class="btn btn-primary create-btn" :disabled="submitting" @click="createTeacher">
        {{ submitting ? '创建中...' : '创建老师和班级' }}
      </button>
    </section>

    <section class="classes-section">
      <div class="list-heading">
        <h2>现有班级</h2>
        <span>{{ teachers.length }} 个班级</span>
      </div>
      <div v-if="loading" class="empty-state">正在加载...</div>
      <div v-else-if="teachers.length === 0" class="empty-state">还没有老师账号，请先创建</div>
      <div v-else class="class-grid">
        <article v-for="teacher in teachers" :key="teacher.id" class="class-card card">
          <div class="class-icon">🏫</div>
          <div class="class-content">
            <h3>{{ teacher.class_name || '未命名班级' }}</h3>
            <p>老师账号：<strong>{{ teacher.username }}</strong></p>
            <span class="student-count">👧 {{ teacher.student_count }} 名学生</span>
          </div>
          <button
            class="delete-btn"
            :disabled="teacher.student_count > 0"
            :title="teacher.student_count > 0 ? '班级中仍有学生，不能删除' : '删除老师账号'"
            @click="removeTeacher(teacher)"
          >删除</button>
        </article>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'

interface TeacherItem {
  id: string
  username: string
  class_name: string | null
  created_at: string
  student_count: number
}

const router = useRouter()
const authStore = useAuthStore()
const teachers = ref<TeacherItem[]>([])
const loading = ref(false)
const submitting = ref(false)
const error = ref('')
const success = ref('')
const form = reactive({ username: '', password: '', className: '' })

onMounted(loadTeachers)

async function loadTeachers() {
  loading.value = true
  const result = await authStore.fetchTeachers()
  teachers.value = (result.data || []) as TeacherItem[]
  if (result.error) error.value = result.error.message
  loading.value = false
}

async function createTeacher() {
  error.value = ''
  success.value = ''
  submitting.value = true
  const result = await authStore.createTeacher(form.username, form.password, form.className)
  submitting.value = false
  if (result.error) {
    error.value = result.error.message || '创建失败，请重试'
    return
  }
  success.value = `已创建老师「${result.data?.username}」和班级「${result.data?.class_name}」`
  form.username = ''
  form.password = ''
  form.className = ''
  await loadTeachers()
}

async function removeTeacher(teacher: TeacherItem) {
  if (teacher.student_count > 0) return
  if (!confirm(`确定删除老师「${teacher.username}」吗？`)) return
  const result = await authStore.deleteTeacher(teacher.id)
  if (result.error) error.value = result.error.message
  else await loadTeachers()
}

async function handleLogout() {
  await authStore.signOut()
  router.push('/login')
}
</script>

<style scoped>
.admin-page { min-height: 100vh; padding: 28px 20px 100px; background: linear-gradient(180deg, #f7f3ff, #fffaf5 50%); }
.admin-header { max-width: 960px; margin: 0 auto 24px; display: flex; justify-content: space-between; gap: 20px; align-items: flex-start; }
.eyebrow { color: #8b5cf6; font-size: 0.76rem; font-weight: 800; letter-spacing: 0.12em; }
.admin-header h1 { margin: 5px 0; font-size: 1.9rem; }
.admin-header p, .section-title p { color: var(--color-text-muted); font-size: 0.88rem; }
.logout-btn, .delete-btn { border: 1px solid #eadff8; background: white; border-radius: 10px; padding: 8px 14px; cursor: pointer; color: #765b8f; }
.create-card, .classes-section { max-width: 960px; margin: 0 auto 24px; }
.create-card { padding: 24px; }
.section-title, .list-heading { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; }
.section-title h2, .list-heading h2 { margin: 0 0 5px; font-size: 1.2rem; }
.admin-badge { padding: 5px 10px; border-radius: 999px; background: #ede9fe; color: #7c3aed; font-size: 0.7rem; font-weight: 800; }
.form-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; margin-top: 22px; }
.form-grid label { display: flex; flex-direction: column; gap: 7px; font-size: 0.84rem; font-weight: 600; }
.create-btn { margin-top: 18px; min-width: 190px; }
.message { margin: 14px 0 0; font-size: 0.84rem; }.message.error { color: var(--color-danger); }.message.success { color: var(--color-success); }
.list-heading { align-items: center; margin-bottom: 12px; }.list-heading span { color: #999; font-size: 0.84rem; }
.class-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; }
.class-card { display: flex; align-items: center; gap: 14px; padding: 18px; }
.class-icon { width: 48px; height: 48px; display: grid; place-items: center; border-radius: 15px; background: #f3edff; font-size: 1.45rem; }
.class-content { flex: 1; min-width: 0; }.class-content h3 { margin: 0 0 5px; font-size: 1rem; }.class-content p { margin: 0 0 7px; color: #777; font-size: 0.8rem; }
.student-count { display: inline-block; padding: 3px 8px; border-radius: 999px; background: #fff0f5; color: #c6537d; font-size: 0.74rem; }
.delete-btn { color: #e05269; border-color: #ffd6dc; }.delete-btn:disabled { cursor: not-allowed; opacity: 0.4; }
.empty-state { padding: 40px 20px; text-align: center; color: #999; background: rgba(255,255,255,.7); border-radius: 16px; }
@media (max-width: 700px) { .form-grid, .class-grid { grid-template-columns: 1fr; }.admin-header { align-items: center; }.admin-header h1 { font-size: 1.55rem; } }
</style>
