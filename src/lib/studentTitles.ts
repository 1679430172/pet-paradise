export const STUDENT_TITLES = [
  { value: '进步之星', icon: '🌟', theme: 'rise' },
  { value: '自律达人', icon: '⏰', theme: 'focus' },
  { value: '热心伙伴', icon: '🤝', theme: 'heart' },
  { value: '勇敢挑战者', icon: '💪', theme: 'brave' },
  { value: '坚持小标兵', icon: '🎯', theme: 'steady' },
  { value: '课堂闪耀之星', icon: '✨', theme: 'legend' },
] as const

export function titleLabel(title?: string | null) {
  if (!title) return ''
  const item = STUDENT_TITLES.find(entry => entry.value === title)
  return `${item?.icon || '🌟'} ${title}`
}

export function titleTheme(title?: string | null) {
  return STUDENT_TITLES.find(entry => entry.value === title)?.theme || 'rise'
}
