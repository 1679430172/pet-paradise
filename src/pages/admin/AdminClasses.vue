<template>
  <div class="admin-page">
    <header class="admin-header">
      <div>
        <span class="eyebrow">ADMIN CONSOLE</span>
        <h1>班级管理</h1>
        <p>管理老师、班级和学生账号</p>
      </div>
      <div class="header-actions">
        <button class="primary-action" @click="showCreateForm = !showCreateForm">
          <span>{{ showCreateForm ? '×' : '+' }}</span>{{ showCreateForm ? '收起' : '新增老师' }}
        </button>
        <button class="logout-btn" @click="handleLogout">退出</button>
      </div>
    </header>

    <section class="overview-grid">
      <article class="metric-card card">
        <span class="metric-icon purple">🏫</span>
        <div>
          <strong>{{ teachers.length }}</strong>
          <span>班级总数</span>
        </div>
      </article>
      <article class="metric-card card">
        <span class="metric-icon pink">👩‍🎓</span>
        <div><strong>{{ totalStudents }}</strong><span>学生总数</span></div>
      </article>
      <article class="registration-card card">
        <div class="registration-copy">
          <span class="metric-icon" :class="registrationEnabled ? 'green' : 'gray'">{{ registrationEnabled ? '✓' : '—' }}</span>
          <div>
            <div class="registration-title">
              <strong>学生自助注册</strong>
              <span class="status-pill" :class="{ enabled: registrationEnabled }">{{ registrationEnabled ? '开放中' : '已关闭' }}</span>
            </div>
            <p>{{ registrationEnabled ? '新学生可以注册并选择班级' : '仅已有账号可以登录' }}</p>
          </div>
        </div>
        <label class="switch" :class="{ disabled: registrationLoading }">
          <input type="checkbox" :checked="registrationEnabled" :disabled="registrationLoading" @change="toggleRegistration" />
          <span class="switch-track"><span></span></span>
        </label>
      </article>
    </section>

    <div v-if="registrationMessage || registrationError" class="notice" :class="{ error: registrationError }" role="status">
      {{ registrationError || registrationMessage }}
    </div>

    <Transition name="form-slide">
    <section v-if="showCreateForm" class="create-card card">
      <div class="section-title">
        <div>
          <h2>新增老师和班级</h2>
          <p>创建登录账号，并同时建立老师负责的班级。</p>
        </div>
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
      <div class="form-actions">
        <button class="secondary-action" :disabled="submitting" @click="showCreateForm = false">取消</button>
        <button class="primary-action submit" :disabled="submitting" @click="createTeacher">{{ submitting ? '正在创建...' : '确认创建' }}</button>
      </div>
    </section>
    </Transition>

    <section class="classes-section">
      <div class="list-heading">
        <div><h2>班级列表</h2><p>点击管理可修改班级信息和学生账号</p></div>
        <div class="search-box"><span>⌕</span><input v-model="searchQuery" placeholder="搜索班级或老师" /></div>
      </div>
      <div v-if="loading" class="empty-state">正在加载...</div>
      <div v-else-if="teachers.length === 0" class="empty-state">还没有老师账号，请先创建</div>
      <div v-else-if="filteredTeachers.length === 0" class="empty-state">没有找到匹配的班级</div>
      <div v-else class="class-grid">
        <article v-for="teacher in filteredTeachers" :key="teacher.id" class="class-card card">
          <div class="class-summary">
            <div class="class-icon">{{ (teacher.class_name || '班').charAt(0) }}</div>
            <div class="class-content">
              <h3>{{ teacher.class_name || '未命名班级' }}</h3>
              <p>老师账号 · <strong>{{ teacher.username }}</strong></p>
            </div>
            <span class="student-count"><strong>{{ teacher.student_count }}</strong> 名学生</span>
            <div class="class-actions">
              <button class="manage-btn" @click="openManage(teacher)">管理</button>
            </div>
          </div>
        </article>
      </div>
    </section>

    <div v-if="managingTeacher" class="drawer-overlay" @click.self="closeManage">
      <section class="manage-drawer" role="dialog" aria-modal="true" aria-labelledby="manage-class-title">
        <header class="drawer-header">
          <div>
            <span class="drawer-label">班级管理</span>
            <h2 id="manage-class-title">{{ managingTeacher.class_name || '未命名班级' }}</h2>
            <p>老师账号：{{ managingTeacher.username }}</p>
          </div>
          <button class="drawer-close" aria-label="关闭" @click="closeManage">×</button>
        </header>

        <div class="drawer-body">
          <section class="manage-box">
            <h3>基本信息</h3>
            <label>班级名称</label>
            <div class="inline-form">
              <input v-model="manageClassName" class="form-input" maxlength="30" />
              <button class="small-btn primary" @click="saveClass(managingTeacher)">保存</button>
            </div>
          </section>
          <section class="manage-box">
            <h3>老师密码</h3>
            <label>设置新的登录密码</label>
            <div class="inline-form">
              <input v-model="teacherPassword" type="password" class="form-input" placeholder="至少 6 位" />
              <button class="small-btn primary" @click="resetTeacherPassword(managingTeacher)">重置</button>
            </div>
          </section>
          <section class="student-section">
            <div class="student-heading"><h3>学生账号</h3><span>{{ students.length }} 人</span></div>
            <div v-if="studentsLoading" class="student-empty">正在加载学生...</div>
            <div v-else-if="students.length === 0" class="student-empty">这个班级还没有学生</div>
            <div v-else class="student-list">
              <div v-for="student in students" :key="student.id" class="student-row">
                <div class="student-avatar">{{ student.username.charAt(0) }}</div>
                <div class="student-info"><strong>{{ student.username }}</strong><span>{{ student.points }} 积分 · {{ formatDate(student.created_at) }}加入</span></div>
                <button class="student-action" @click="openStudentPassword(student)">重置密码</button>
                <button class="student-action danger" @click="removeStudent(student, managingTeacher)">删除</button>
              </div>
            </div>
          </section>
          <section class="danger-zone">
            <div><strong>删除老师账号</strong><span>{{ managingTeacher.student_count > 0 ? '请先清空该班级的学生账号' : '此操作无法撤销' }}</span></div>
            <button class="delete-btn" :disabled="managingTeacher.student_count > 0" @click="removeTeacher(managingTeacher)">删除老师</button>
          </section>
        </div>
      </section>
    </div>

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
import { computed, onMounted, reactive, ref } from 'vue'
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
const registrationEnabled = ref(true)
const registrationLoading = ref(true)
const registrationMessage = ref('')
const registrationError = ref('')
const showCreateForm = ref(false)
const searchQuery = ref('')
const totalStudents = computed(() => teachers.value.reduce((sum, teacher) => sum + teacher.student_count, 0))
const filteredTeachers = computed(() => {
  const keyword = searchQuery.value.trim().toLowerCase()
  if (!keyword) return teachers.value
  return teachers.value.filter(teacher =>
    teacher.username.toLowerCase().includes(keyword) ||
    (teacher.class_name || '').toLowerCase().includes(keyword)
  )
})
const managingTeacher = computed(() => teachers.value.find(teacher => teacher.id === expandedTeacherId.value) || null)

onMounted(async () => {
  await Promise.all([loadTeachers(), loadRegistrationSetting()])
})

async function loadRegistrationSetting() {
  registrationLoading.value = true
  const result = await authStore.fetchRegistrationEnabled()
  registrationEnabled.value = result.data
  if (result.error) registrationError.value = '注册设置加载失败，请刷新后重试。'
  registrationLoading.value = false
}

async function toggleRegistration() {
  const nextValue = !registrationEnabled.value
  registrationLoading.value = true
  registrationError.value = ''
  registrationMessage.value = ''
  const result = await authStore.updateRegistrationEnabled(nextValue)
  if (result.error) registrationError.value = result.error.message || '注册设置保存失败'
  else {
    registrationEnabled.value = result.data === true
    registrationMessage.value = nextValue ? '设置已保存，学生现在可以注册账号。' : '设置已保存，学生注册入口已关闭。'
  }
  registrationLoading.value = false
}

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
  showCreateForm.value = false
}

async function removeTeacher(teacher: TeacherItem) {
  if (teacher.student_count > 0) return
  if (!confirm(`确定删除老师「${teacher.username}」吗？`)) return
  const result = await authStore.deleteTeacher(teacher.id)
  if (result.error) error.value = result.error.message
  else await loadTeachers()
}

async function openManage(teacher: TeacherItem) {
  expandedTeacherId.value = teacher.id
  manageClassName.value = teacher.class_name || ''
  teacherPassword.value = ''
  await loadStudents(teacher.id)
}

function closeManage() {
  expandedTeacherId.value = null
  students.value = []
  teacherPassword.value = ''
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
.admin-page { --admin-purple:#7657d5; --admin-ink:#292238; min-height:100vh; padding:38px 28px 100px; background:#f8f7fb; color:var(--admin-ink); }
.admin-header,.overview-grid,.create-card,.classes-section,.notice { max-width:1120px; margin-left:auto; margin-right:auto; }
.admin-header { margin-bottom:28px; display:flex; justify-content:space-between; align-items:flex-end; gap:24px; }
.eyebrow { color:#9a8ab6; font-size:.68rem; font-weight:800; letter-spacing:.16em; }
.admin-header h1 { margin:6px 0 4px; font-size:2rem; letter-spacing:-.04em; }
.admin-header p,.section-title p,.list-heading p { margin:0; color:#8a8392; font-size:.86rem; }
.header-actions,.form-actions { display:flex; gap:10px; }
.primary-action,.secondary-action,.logout-btn { border:0; border-radius:11px; padding:10px 16px; cursor:pointer; font-weight:700; }
.primary-action { color:white; background:var(--admin-purple); box-shadow:0 6px 16px rgba(118,87,213,.2); }
.primary-action span { margin-right:7px; font-size:1.1rem; }
.primary-action:disabled { opacity:.55; cursor:wait; }
.secondary-action,.logout-btn { color:#6f6877; background:white; border:1px solid #e7e3ec; }
.overview-grid { display:grid; grid-template-columns:180px 180px minmax(360px,1fr); gap:14px; margin-bottom:28px; }
.metric-card,.registration-card { padding:18px; border:1px solid #ece8f0; box-shadow:0 3px 14px rgba(57,42,74,.05); }
.metric-card { display:flex; align-items:center; gap:13px; }
.metric-icon { width:42px; height:42px; display:grid; place-items:center; flex-shrink:0; border-radius:12px; font-weight:800; }
.metric-icon.purple { background:#eee9ff; }.metric-icon.pink { background:#ffebf2; }.metric-icon.green { color:#16844b; background:#e5f9ee; }.metric-icon.gray { color:#817987; background:#f0eef2; }
.metric-card div { display:flex; flex-direction:column; }.metric-card strong { font-size:1.35rem; line-height:1.1; }.metric-card span:last-child { margin-top:4px; color:#918997; font-size:.75rem; }
.registration-card { display:flex; align-items:center; justify-content:space-between; gap:16px; }
.registration-copy { display:flex; align-items:center; gap:12px; }.registration-title { display:flex; align-items:center; gap:8px; }.registration-title strong { font-size:.92rem; }.registration-copy p { margin:5px 0 0; color:#918997; font-size:.76rem; }
.status-pill { padding:3px 7px; border-radius:999px; color:#827989; background:#f0eef2; font-size:.66rem; font-weight:700; }.status-pill.enabled { color:#18854c; background:#e5f9ee; }
.switch { cursor:pointer; }.switch.disabled { opacity:.55; cursor:wait; }.switch input { position:absolute; opacity:0; pointer-events:none; }.switch-track { width:46px; height:26px; display:block; padding:3px; border-radius:99px; background:#d8d4dc; transition:.2s; }.switch-track span { width:20px; height:20px; display:block; border-radius:50%; background:white; box-shadow:0 1px 4px rgba(0,0,0,.18); transition:.2s; }.switch input:checked + .switch-track { background:#38bd72; }.switch input:checked + .switch-track span { transform:translateX(20px); }
.notice { box-sizing:border-box; margin-top:-14px; margin-bottom:22px; padding:10px 14px; border-radius:10px; color:#187e49; background:#eaf9f1; font-size:.8rem; }.notice.error { color:#c94359; background:#fff0f2; }
.create-card { box-sizing:border-box; margin-bottom:28px; padding:24px; border:1px solid #e8e2ef; box-shadow:0 8px 28px rgba(57,42,74,.08); }
.section-title h2,.list-heading h2 { margin:0 0 5px; font-size:1.12rem; }
.form-grid { display:grid; grid-template-columns:repeat(3,1fr); gap:14px; margin-top:20px; }.form-grid label { display:flex; flex-direction:column; gap:7px; color:#514b59; font-size:.78rem; font-weight:700; }.form-grid .form-input { border-color:#e5dfea; background:#fbfafc; }
.form-actions { justify-content:flex-end; margin-top:20px; }.primary-action.submit { min-width:110px; }
.message { margin:14px 0 0; font-size:.8rem; }.message.error { color:var(--color-danger); }.message.success { color:var(--color-success); }
.form-slide-enter-active,.form-slide-leave-active { transition:.2s ease; }.form-slide-enter-from,.form-slide-leave-to { opacity:0; transform:translateY(-8px); }
.classes-section { margin-bottom:24px; }.list-heading { display:flex; align-items:flex-end; justify-content:space-between; gap:18px; margin-bottom:14px; }
.search-box { width:230px; display:flex; align-items:center; gap:8px; padding:9px 12px; border:1px solid #e7e2eb; border-radius:10px; background:white; color:#999; }.search-box input { width:100%; border:0; outline:0; background:transparent; font:inherit; font-size:.8rem; }
.class-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:14px; align-items:start; }.class-card { padding:0; overflow:hidden; border:1px solid #ebe6ef; box-shadow:0 3px 14px rgba(57,42,74,.045); }
.class-summary { display:flex; align-items:center; gap:14px; padding:18px; }.class-icon { width:44px; height:44px; display:grid; place-items:center; flex-shrink:0; border-radius:13px; color:#7156bd; background:#eee9ff; font-size:1.05rem; font-weight:800; }.class-content { flex:1; min-width:0; }.class-content h3 { margin:0 0 5px; font-size:.98rem; }.class-content p { margin:0; color:#8e8794; font-size:.75rem; }.class-content p strong { color:#625b69; }
.student-count { color:#8c8492; font-size:.73rem; white-space:nowrap; }.student-count strong { color:#443c4d; font-size:.98rem; }
.manage-btn { border:1px solid #ded5f3; border-radius:9px; padding:7px 12px; color:#7054c4; background:#f5f2fd; cursor:pointer; font-weight:700; }
.drawer-overlay { position:fixed; inset:0; z-index:200; display:grid; place-items:center; padding:24px; background:rgba(35,28,43,.42); backdrop-filter:blur(3px); }.manage-drawer { width:min(760px,100%); max-height:calc(100dvh - 48px); display:flex; flex-direction:column; overflow:hidden; border:1px solid #e5dfeb; border-radius:18px; background:#f8f7fb; box-shadow:0 24px 70px rgba(40,30,50,.24); animation:modal-in .18s ease-out; }.drawer-header { flex-shrink:0; display:flex; justify-content:space-between; align-items:flex-start; padding:22px 24px 18px; border-bottom:1px solid #e9e4ed; background:white; }.drawer-label { color:#8066ca; font-size:.68rem; font-weight:800; letter-spacing:.12em; }.drawer-header h2 { margin:5px 0 3px; font-size:1.35rem; }.drawer-header p { margin:0; color:#8e8794; font-size:.78rem; }.drawer-close { width:36px; height:36px; border:1px solid #e5e0e9; border-radius:10px; color:#766e7d; background:white; cursor:pointer; font-size:1.35rem; }.drawer-body { display:grid; grid-template-columns:1fr 1fr; gap:14px; padding:20px 24px 26px; overflow-y:auto; }.manage-box { padding:17px; border:1px solid #e8e3ec; border-radius:13px; background:white; }.manage-box h3,.student-heading h3 { margin:0 0 13px; font-size:.9rem; }.manage-box label { display:block; margin-bottom:7px; color:#857d8a; font-size:.74rem; }.inline-form { display:flex; gap:8px; }.inline-form .form-input { min-width:0; }.small-btn { border:1px solid #e0dae6; background:#fff; color:#6e6477; border-radius:9px; padding:8px 13px; cursor:pointer; white-space:nowrap; }.small-btn.primary { border-color:#7657d5; color:white; background:#7657d5; }
.student-section { grid-column:1/-1; }.student-heading { display:flex; justify-content:space-between; align-items:center; }.student-heading span { color:#999; font-size:.75rem; }.student-list { border:1px solid #ebe6ef; border-radius:12px; overflow:hidden; }.student-row { display:flex; align-items:center; gap:11px; padding:11px 13px; background:white; }.student-row + .student-row { border-top:1px solid #f0ecf2; }.student-avatar { width:32px; height:32px; display:grid; place-items:center; flex-shrink:0; border-radius:9px; background:#f3eaf0; color:#b24f7c; font-weight:700; }.student-info { flex:1; display:flex; flex-direction:column; min-width:0; }.student-info strong { font-size:.82rem; }.student-info span { color:#999; font-size:.7rem; margin-top:2px; }.student-action { border:0; background:#f1eef6; color:#6d6377; border-radius:8px; padding:6px 9px; cursor:pointer; font-size:.72rem; }.student-action.danger { color:#cf5064; background:#fff0f2; }.student-empty,.empty-state { padding:34px 20px; text-align:center; color:#999; background:white; border:1px dashed #ded9e3; border-radius:12px; font-size:.8rem; }
.danger-zone { grid-column:1/-1; padding-top:16px; border-top:1px solid #e5e0e9; display:flex; align-items:center; justify-content:space-between; gap:14px; }.danger-zone div { display:flex; flex-direction:column; gap:3px; }.danger-zone strong { color:#b74759; font-size:.78rem; }.danger-zone span { color:#a39ca8; font-size:.7rem; }.delete-btn { border:1px solid #f0cbd1; background:white; border-radius:9px; padding:7px 11px; color:#cf4e63; cursor:pointer; }.delete-btn:disabled { opacity:.4; cursor:not-allowed; }
.dialog-overlay { position:fixed; inset:0; z-index:300; display:grid; place-items:center; padding:20px; background:rgba(36,28,43,.5); backdrop-filter:blur(3px); }.password-dialog { width:min(380px,100%); padding:22px; }.password-dialog h3 { margin:0 0 7px; }.password-dialog p { color:#777; font-size:.84rem; margin-bottom:15px; }.dialog-actions { display:flex; justify-content:flex-end; gap:9px; margin-top:16px; }
@keyframes modal-in { from { transform:translateY(10px) scale(.985); opacity:.4; } to { transform:translateY(0) scale(1); opacity:1; } }
@media (max-width:900px) { .overview-grid { grid-template-columns:repeat(2,1fr); }.registration-card { grid-column:1/-1; }.class-grid { grid-template-columns:1fr; }.class-card.expanded { grid-column:auto; } }
@media (max-width:700px) { .admin-page { padding:24px 16px 90px; }.admin-header { align-items:flex-start; }.admin-header h1 { font-size:1.6rem; }.header-actions { flex-direction:column; }.overview-grid { grid-template-columns:1fr 1fr; }.metric-card { padding:14px; }.registration-card { flex-direction:row; }.form-grid,.manage-grid { grid-template-columns:1fr; }.list-heading { align-items:stretch; flex-direction:column; }.search-box { box-sizing:border-box; width:100%; }.class-summary { flex-wrap:wrap; }.class-content { min-width:150px; }.student-count { order:4; margin-left:58px; }.student-row { flex-wrap:wrap; }.student-info { min-width:140px; }.drawer-overlay { padding:12px; }.manage-drawer { max-height:calc(100dvh - 24px); }.drawer-body { grid-template-columns:1fr; padding:16px; }.student-section,.danger-zone { grid-column:auto; }.danger-zone { align-items:flex-start; } }
</style>
