import { LEVEL_THRESHOLDS, MAX_LEVEL } from './constants'

type PetExperience = { level: number; xp?: number }

export function levelXp(pet: PetExperience): { current: number; max: number } {
  const previous = LEVEL_THRESHOLDS[pet.level - 1] ?? 0
  const next = LEVEL_THRESHOLDS[pet.level] ?? previous
  const max = Math.max(0, next - previous)
  return { current: Math.max(0, Math.min(max, (pet.xp || 0) - previous)), max }
}

export function xpProgress(pet: PetExperience): number {
  if (pet.level >= MAX_LEVEL) return 100
  const { current, max } = levelXp(pet)
  return max > 0 ? (current / max) * 100 : 100
}

export function xpLabel(pet: PetExperience): string {
  if (pet.level >= MAX_LEVEL) return '已满级'
  const { current, max } = levelXp(pet)
  return `${current}/${max} XP`
}
