import { supabase } from './supabase'

export type RankingPeriod = 'year' | 'month' | 'week' | 'all'
export const RANKING_PERIODS: { value: RankingPeriod; label: string }[] = [
  { value: 'year', label: '本年' }, { value: 'month', label: '本月' },
  { value: 'week', label: '本周' }, { value: 'all', label: '全部' },
]

export function rankingRange(period: RankingPeriod, now = new Date()) {
  if (period === 'all') return { start: '', end: '' }
  const offset = 8 * 3600_000
  const local = new Date(now.getTime() + offset)
  const year = local.getUTCFullYear(), month = local.getUTCMonth(), day = local.getUTCDate()
  let start: number, end: number
  if (period === 'year') {
    start = Date.UTC(year, 0, 1); end = Date.UTC(year + 1, 0, 1)
  } else if (period === 'month') {
    start = Date.UTC(year, month, 1); end = Date.UTC(year, month + 1, 1)
  } else {
    start = Date.UTC(year, month, day - (local.getUTCDay() + 6) % 7)
    end = start + 7 * 86400_000
  }
  return { start: new Date(start - offset).toISOString(), end: new Date(end - offset).toISOString() }
}

// Read all pages, including historical earnings; balances and spending are not ranking inputs.
export async function readPeriodLeaderboard(teacherId: string, period: RankingPeriod) {
  const range = rankingRange(period)
  const students: { id: string; username: string; points: number; pet_level: number; pet_name: string }[] = []
  const pageSize = 500
  for (let from = 0; ; from += pageSize) {
    const { data, error } = await supabase.from('profiles').select('id,username')
      .eq('teacher_id', teacherId).eq('role', 'student').order('id').range(from, from + pageSize - 1)
    if (error) throw error
    students.push(...(data || []).map(s => ({ ...s, points: 0, pet_level: 0, pet_name: '未领养' })))
    if (!data || data.length < pageSize) break
  }
  const totals = new Map(students.map(s => [s.id, s]))
  for (let from = 0; ; from += pageSize) {
    let query = supabase.from('point_earnings').select('source_id,student_id,points')
      .eq('teacher_id', teacherId).order('source_id').range(from, from + pageSize - 1)
    if (range.start) query = query.gte('created_at', range.start).lt('created_at', range.end)
    const { data, error } = await query
    if (error) throw error
    const revoked = new Set<string>()
    const taskIds = (data || []).filter(e => e.source_id.startsWith('task:')).map(e => e.source_id.slice(5))
    for (let i = 0; i < taskIds.length; i += 100) {
      const result = await supabase.from('task_completions').select('id').in('id', taskIds.slice(i, i + 100)).not('revoked_at', 'is', null)
      if (result.error) throw result.error
      for (const row of result.data || []) revoked.add(`task:${row.id}`)
    }
    for (const earning of data || []) {
      const student = totals.get(earning.student_id)
      if (student && !revoked.has(earning.source_id)) student.points += earning.points
    }
    if (!data || data.length < pageSize) break
  }
  students.sort((a, b) => b.points - a.points || a.username.localeCompare(b.username, 'zh-CN') || a.id.localeCompare(b.id))
  return { entries: students, weekStart: range.start, weekEnd: range.end }
}
