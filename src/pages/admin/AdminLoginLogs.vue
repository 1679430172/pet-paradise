<template>
  <div class="login-logs-page">
    <header class="logs-header">
      <div>
        <span class="eyebrow">ADMIN CONSOLE</span>
        <h1>登录日志</h1>
        <p>查看成功登录的账号、客户端 IP 和访问地址</p>
      </div>
      <button class="btn btn-outline" @click="logout">退出</button>
    </header>

    <section class="card logs-card">
      <div>
        <div class="log-actions">
          <button class="btn btn-outline" :disabled="loading" @click="loadPage(0)">刷新</button>
        </div>
        <div v-if="rows.length" class="table-scroll" tabindex="0" aria-label="登录日志列表">
          <table>
            <thead>
              <tr><th>登录时间</th><th>账号</th><th>角色</th><th>班级</th><th>客户端 IP</th><th>访问地址</th></tr>
            </thead>
            <tbody>
              <tr v-for="row in rows" :key="row.id">
                <td>{{ dateTime.format(new Date(row.logged_in_at)) }}</td>
                <td>{{ row.username }}</td>
                <td>{{ roleLabels[row.account_role] || row.account_role }}</td>
                <td>{{ row.class_name || '—' }}</td>
                <td>{{ row.client_ip || '未获取' }}</td>
                <td class="access-url">{{ row.access_url || '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-else-if="!loading && !errorMessage">暂无登录记录</p>
        <div v-if="pageIndex > 0 || hasNextPage" class="log-actions pagination">
          <button class="btn btn-outline" :disabled="loading || pageIndex === 0" @click="loadPage(pageIndex - 1)">上一页</button>
          <span>第 {{ pageIndex + 1 }} 页</span>
          <button class="btn btn-outline" :disabled="loading || !hasNextPage" @click="loadPage(pageIndex + 1)">下一页</button>
        </div>
      </div>
      <p v-if="loading" role="status">正在加载登录日志…</p>
      <p v-if="errorMessage" class="error-message" role="alert">{{ errorMessage }}</p>
    </section>
  </div>
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { loginAuditEmail, loginAuditSupabase } from '../../lib/supabase'
import { useAuthStore } from '../../stores/auth'

interface LoginLog {
  id: number
  username: string
  account_role: string
  class_name: string | null
  client_ip: string | null
  access_url: string | null
  logged_in_at: string
}

const PAGE_SIZE = 50
const roleLabels: Record<string, string> = { admin: '管理员', teacher: '老师', student: '学生' }
const dateTime = new Intl.DateTimeFormat('zh-CN', {
  dateStyle: 'short', timeStyle: 'medium', timeZone: 'Asia/Shanghai',
})
const router = useRouter()
const authStore = useAuthStore()
const loading = ref(false)
const errorMessage = ref('')
const rows = ref<LoginLog[]>([])
const pageIndex = ref(0)
const hasNextPage = ref(false)
const cursors: (number | null)[] = [null]
let request: AbortController | undefined

async function loadPage(index: number) {
  const profile = authStore.user
  if (loading.value || !authStore.isAdmin || !profile) return
  const current = new AbortController()
  request = current
  loading.value = true
  errorMessage.value = ''
  try {
    const { data: { session } } = await loginAuditSupabase.auth.getSession()
    if (current.signal.aborted) return
    if (session?.user.email !== loginAuditEmail(profile.id)) {
      rows.value = []
      errorMessage.value = '请退出后重新登录管理员账号。如仍无法查看，请检查服务器上的日志权限配置。'
      return
    }
    const { data, error } = await loginAuditSupabase.rpc('read_login_logs', {
      p_before_id: cursors[index] ?? null,
    }).abortSignal(current.signal)
    if (current.signal.aborted) return
    if (error) {
      if (error.code === '42501') rows.value = []
      errorMessage.value = error.code === '42501'
        ? '当前管理员账号尚未获得登录日志查看权限'
        : '登录日志加载失败，请稍后重试'
      return
    }
    const records: LoginLog[] = data ?? []
    rows.value = records.slice(0, PAGE_SIZE)
    pageIndex.value = index
    cursors.length = index + 1
    hasNextPage.value = records.length > PAGE_SIZE
    const lastRow = rows.value.at(-1)
    if (hasNextPage.value && lastRow) cursors.push(lastRow.id)
  } catch {
    if (!current.signal.aborted) errorMessage.value = '登录日志加载失败，请稍后重试'
  } finally {
    if (request === current) {
      request = undefined
      loading.value = false
    }
  }
}

async function logout() {
  request?.abort()
  rows.value = []
  await authStore.signOut()
  await router.push('/login')
}

onMounted(() => { void loadPage(0) })
onBeforeUnmount(() => request?.abort())
</script>

<style scoped>
.login-logs-page {
  min-height: 100vh;
  padding: 38px 28px 100px;
  background: #f8f7fb;
  color: #292238;
}
.logs-header, .logs-card { max-width: 1120px; margin-inline: auto; }
.logs-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 24px;
}
.eyebrow { color: #77668e; font-size: .68rem; font-weight: 800; letter-spacing: .16em; }
h1 { margin: 6px 0 4px; font-size: 2rem; }
.logs-header p { margin: 0; color: #6f6877; font-size: .86rem; }
.logs-card { padding: 24px; border: 1px solid #ece8f0; border-radius: 18px; background: #fff; }
.log-actions { display: flex; flex-wrap: wrap; align-items: center; gap: 10px; }
.log-actions .btn { width: auto; }
.btn {
  padding: 9px 14px;
  border-radius: 10px;
  font-size: .84rem;
  font-weight: 700;
}
.btn-outline { border: 1px solid #e7e3ec; background: #fff; color: #6f6877; }
.btn:disabled { opacity: .55; cursor: default; }
.table-scroll { overflow-x: auto; margin-top: 16px; }
table { width: 100%; min-width: 760px; border-collapse: collapse; font-size: .84rem; }
th, td { padding: 12px 10px; border-bottom: 1px solid #ece8f0; text-align: left; }
th { background: #f6f3fc; }
td:first-child { white-space: nowrap; }
.access-url { max-width: 320px; overflow-wrap: anywhere; }
.pagination { justify-content: flex-end; margin-top: 16px; }
.error-message { color: #a32240; }
@media (max-width: 700px) {
  .login-logs-page { padding: 24px 16px 90px; }
  .logs-card { padding: 16px; }
  h1 { font-size: 1.6rem; }
}
</style>
