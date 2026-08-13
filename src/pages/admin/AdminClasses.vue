<template>
  <div class="admin-page">
    <header class="admin-header">
      <div>
        <span class="eyebrow">管理员控制台</span>
        <h1>班级与老师</h1>
        <p>统一管理老师账号、班级信息，以及各班学生账号。</p>
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
        <article v-for="teacher in teachers" :key="teacher.id" class="class-card card" :class="{ expanded: expandedTeacherId === teacher.id }">
          <div class="class-summary">
            <div class="class-icon">🏫</div>
            <div class="class-content">
              <h3>{{ teacher.class_name || '未命名班级' }}</h3>
              <p>老师账号：<strong>{{ teacher.username }}</strong></p>
              <span class="student-count">👧 {{ teacher.student_count }} 名学生</span>
            </div>
            <div class="class-actions">
              <button class="manage-btn" @click="openManage(teacher)">{{ expandedTeacherId === teacher.id ? '收起' : '管理' }}</button>
              <button
                class="delete-btn"
                :disabled="teacher.student_count > 0"
                :title="teacher.student_count > 0 ? '班级中仍有学生，不能删除' : '删除老师账号'"
                @click="removeTeacher(teacher)"
              >删除</button>
            </div>
          </div>

          <div v-if="expandedTeacherId === teacher.id" class="manage-panel">
            <div class="manage-grid">
              <div class="manage-box">
                <h4>修改班级名称</h4>
                <div class="inline-form">
                  <input v-model="manageClassName" class="form-input" maxlength="30" />
                  <button class="small-btn primary" @click="saveClass(teacher)">保存</button>
                </div>
              </div>
              <div class="manage-box">
                <h4>重置老师密码</h4>
                <div class="inline-form">
                  <input v-model="teacherPassword" type="password" class="form-input" placeholder="输入至少 6 位新密码" />
                  <button class="small-btn primary" @click="resetTeacherPassword(teacher)">重置</button>
                </div>
              </div>
            </div>

            <div class="student-section">
              <div class="student-heading">
                <h4>班级学生</h4>
                <span>{{ students.length }} 人</span>
              </div>
              <div v-if="studentsLoading" class="student-empty">正在加载学生...</div>
              <div v-else-if="students.length === 0" class="student-empty">这个班级还没有学生</div>
              <div v-else class="student-list">
                <div v-for="student in students" :key="student.id" class="student-row">
                  <div class="student-avatar">{{ student.username.charAt(0) }}</div>
                  <div class="student-info">
                    <strong>{{ student.username }}</strong>
                    <span>{{ student.points }} 积分 · {{ formatDate(student.created_at) }}加入</span>
                  </div>
                  <button class="student-action" @click="openStudentPassword(student)">重置密码</button>
                  <button class="student-action danger" @click="removeStudent(student, teacher)">删除</button>
                </div>
              </div>
            </div>
          </div>
        </article>
      </div>
    </section>

    <div v-if="passwordStudent" class="dialog-overlay" @click.self="closeStudentPassword">
      <div class="password-dialog card">
        <h3>重置学生密码</h3>
        <p>学生账号：<strong>{{ passwordStudent.username }}</strong></p>
        <input v-model="studentPassword" type="password" class="form-input" placeholder="输入至少 6 位新密码" />
        <p v-if="dialogError" class="message error">{{ dialogError }}</p>
        <div class="dialog-actions">
          <button class="small-btn" @click="closeStudentPassword">取消</button>
          <button class="small-btn primary" @click="resetStudentPassword">确认重置</button>
        </div>
      </div>
    </div>
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

interface StudentItem {
  id: string
  username: string
  points: number
  class_name: string | null
  created_at: string
}

const router = useRouter()
const authStore = useAuthStore()
const teachers = ref<TeacherItem[]>([])
const loading = ref(false)
const submitting = ref(false)
const error = ref('')
const success = ref('')
const form = reactive({ username: '', password: '', className: '' })
const expandedTeacherId = ref<string | null>(null)
const students = ref<StudentItem[]>([])
const studentsLoading = ref(false)
const manageClassName = ref('')
const teacherPassword = ref('')
const passwordStudent = ref<StudentItem | null>(null)
const studentPassword = ref('')
const dialogError = ref('')

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

async function openManage(teacher: TeacherItem) {
  if (expandedTeacherId.value === teacher.id) {
    expandedTeacherId.value = null
    return
  }
  expandedTeacherId.value = teacher.id
  manageClassName.value = teacher.class_name || ''
  teacherPassword.value = ''
  await loadStudents(teacher.id)
}

async function loadStudents(teacherId: string) {
  studentsLoading.value = true
  const result = await authStore.fetchTeacherStudents(teacherId)
  students.value = (result.data || []) as StudentItem[]
  if (result.error) error.value = result.error.message
  studentsLoading.value = false
}

async function saveClass(teacher: TeacherItem) {
  error.value = ''
  success.value = ''
  const result = await authStore.updateTeacherClass(teacher.id, manageClassName.value)
  if (result.error) error.value = result.error.message
  else {
    success.value = `班级名称已修改为「${manageClassName.value.trim()}」`
    await loadTeachers()
    expandedTeacherId.value = teacher.id
  }
}

async function resetTeacherPassword(teacher: TeacherItem) {
  error.value = ''
  success.value = ''
  const result = await authStore.resetAccountPassword(teacher.id, teacherPassword.value, 'teacher')
  if (result.error) error.value = result.error.message
  else {
    success.value = `老师「${teacher.username}」的密码已重置`
    teacherPassword.value = ''
  }
}

function openStudentPassword(student: StudentItem) {
  passwordStudent.value = student
  studentPassword.value = ''
  dialogError.value = ''
}

function closeStudentPassword() {
  passwordStudent.value = null
  studentPassword.value = ''
  dialogError.value = ''
}

async function resetStudentPassword() {
  if (!passwordStudent.value) return
  const result = await authStore.resetAccountPassword(passwordStudent.value.id, studentPassword.value, 'student')
  if (result.error) dialogError.value = result.error.message
  else {
    success.value = `学生「${passwordStudent.value.username}」的密码已重置`
    closeStudentPassword()
  }
}

async function removeStudent(student: StudentItem, teacher: TeacherItem) {
  if (!confirm(`确定删除学生「${student.username}」吗？其宠物和日记也会一并删除。`)) return
  const result = await authStore.deleteManagedStudent(student.id, teacher.id)
  if (result.error) error.value = result.error.message
  else {
    success.value = `已删除学生「${student.username}」`
    await Promise.all([loadStudents(teacher.id), loadTeachers()])
    expandedTeacherId.value = teacher.id
  }
}

function formatDate(value: string) {
  return new Date(value).toLocaleDateString('zh-CN')
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
.class-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; align-items: start; }
.class-card { padding: 18px; }.class-card.expanded { grid-column: 1 / -1; }
.class-summary { display: flex; align-items: center; gap: 14px; }
.class-icon { width: 48px; height: 48px; display: grid; place-items: center; border-radius: 15px; background: #f3edff; font-size: 1.45rem; }
.class-content { flex: 1; min-width: 0; }.class-content h3 { margin: 0 0 5px; font-size: 1rem; }.class-content p { margin: 0 0 7px; color: #777; font-size: 0.8rem; }
.student-count { display: inline-block; padding: 3px 8px; border-radius: 999px; background: #fff0f5; color: #c6537d; font-size: 0.74rem; }
.class-actions { display: flex; flex-direction: column; gap: 7px; }
.manage-btn { border: 0; background: #ede9fe; color: #7c3aed; border-radius: 9px; padding: 7px 12px; cursor: pointer; font-weight: 600; }
.delete-btn { color: #e05269; border-color: #ffd6dc; }.delete-btn:disabled { cursor: not-allowed; opacity: 0.4; }
.manage-panel { margin-top: 18px; padding-top: 18px; border-top: 1px solid #f0e8f8; }
.manage-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 14px; }
.manage-box { padding: 14px; border-radius: 13px; background: #faf8fd; }.manage-box h4, .student-heading h4 { margin: 0 0 10px; font-size: 0.88rem; }
.inline-form { display: flex; gap: 8px; }.inline-form .form-input { min-width: 0; }
.small-btn { border: 1px solid #e6dced; background: #fff; color: #765b8f; border-radius: 9px; padding: 8px 13px; cursor: pointer; white-space: nowrap; }
.small-btn.primary { border-color: transparent; color: white; background: linear-gradient(135deg, #ec5ca8, #8b5cf6); }
.student-section { margin-top: 16px; }.student-heading { display: flex; justify-content: space-between; align-items: center; }.student-heading span { color: #999; font-size: .78rem; }
.student-list { border: 1px solid #f0e8f5; border-radius: 13px; overflow: hidden; }
.student-row { display: flex; align-items: center; gap: 11px; padding: 11px 13px; background: white; }.student-row + .student-row { border-top: 1px solid #f4eef7; }
.student-avatar { width: 34px; height: 34px; display: grid; place-items: center; flex-shrink: 0; border-radius: 50%; background: #ffe6f0; color: #cf5c88; font-weight: 700; }
.student-info { flex: 1; display: flex; flex-direction: column; min-width: 0; }.student-info strong { font-size: .86rem; }.student-info span { color: #999; font-size: .72rem; margin-top: 2px; }
.student-action { border: 0; background: #f3eff8; color: #715b83; border-radius: 8px; padding: 6px 9px; cursor: pointer; font-size: .74rem; }.student-action.danger { color: #df5067; background: #fff0f2; }
.student-empty { padding: 22px; text-align: center; color: #aaa; font-size: .82rem; background: #fafafa; border-radius: 12px; }
.dialog-overlay { position: fixed; inset: 0; z-index: 300; display: grid; place-items: center; padding: 20px; background: rgba(44, 32, 50, .45); }
.password-dialog { width: min(380px, 100%); padding: 22px; }.password-dialog h3 { margin: 0 0 7px; }.password-dialog p { color: #777; font-size: .84rem; margin-bottom: 15px; }
.dialog-actions { display: flex; justify-content: flex-end; gap: 9px; margin-top: 16px; }
.empty-state { padding: 40px 20px; text-align: center; color: #999; background: rgba(255,255,255,.7); border-radius: 16px; }
@media (max-width: 700px) { .form-grid, .class-grid, .manage-grid { grid-template-columns: 1fr; }.class-card.expanded { grid-column: auto; }.admin-header { align-items: center; }.admin-header h1 { font-size: 1.55rem; }.student-row { flex-wrap: wrap; }.student-info { min-width: 140px; } }
</style>
