// 宠物种类
export const PET_SPECIES = ['cat', 'dog', 'rabbit', 'hamster', 'bird', 'turtle'] as const
export type PetSpecies = typeof PET_SPECIES[number]

export const PET_SPECIES_LABELS: Record<PetSpecies, string> = {
  cat: '小猫',
  dog: '小狗',
  rabbit: '兔子',
  hamster: '仓鼠',
  bird: '小鸟',
  turtle: '乌龟',
}

// 宠物颜色
export const PET_COLORS: string[] = ['#FFB6C1', '#87CEEB', '#98FB98', '#DDA0DD', '#F0E68C', '#FFA07A']

// 动作配置（去掉冷却，改为积分消耗）
export const ACTIONS = {
  feed: { xp: 10, statKey: 'hunger' as const, statGain: 30 },
  play: { xp: 15, statKey: 'happiness' as const, statGain: 25 },
  clean: { xp: 8, statKey: 'cleanliness' as const, statGain: 40 },
} as const

// 默认积分消耗配置
export const DEFAULT_ACTION_COSTS = { feed: 5, play: 8, clean: 3 }

export const DIARY_XP = 20
export const PHOTO_XP = 25
export const LIKE_XP = 5

// 等级上限
export const MAX_LEVEL = 20

// 等级经验值表（1..20）
export const LEVEL_THRESHOLDS = [
  0,      // Level 1
  50,     // Level 2
  120,    // Level 3
  220,    // Level 4
  350,    // Level 5
  520,    // Level 6
  730,    // Level 7
  1000,   // Level 8
  1350,   // Level 9
  1800,   // Level 10
  2350,   // Level 11
  3000,   // Level 12
  3800,   // Level 13
  4750,   // Level 14
  5850,   // Level 15
  7150,   // Level 16
  8650,   // Level 17
  10400,  // Level 18
  12400,  // Level 19
  14700,  // Level 20
]

// 形态阶段：Lv.1-3 蛋 / Lv.4-8 幼年（蛋壳逐渐破裂）/ Lv.9-13 青年 / Lv.14-19 成年 / Lv.20 完全体
export const PET_STAGES = ['egg', 'baby', 'teen', 'adult', 'final'] as const
export type PetStage = typeof PET_STAGES[number]

export const PET_STAGE_LABELS: Record<PetStage, string> = {
  egg: '蛋',
  baby: '幼年',
  teen: '青年',
  adult: '成年',
  final: '完全体',
}

export function getPetStage(level: number): PetStage {
  if (level >= 20) return 'final'
  if (level >= 14) return 'adult'
  if (level >= 9) return 'teen'
  if (level >= 4) return 'baby'
  return 'egg'
}

// 静态图片路径：/assets/pets/{species}_{stage}.png
export function getPetImage(species: string, level: number): string {
  return `/assets/pets/${species}_${getPetStage(level)}.png`
}

export function isPetMaxed(level: number): boolean {
  return level >= MAX_LEVEL
}

// 等级解锁内容
export const LEVEL_UNLOCKS: Record<number, string> = {
  2: '配饰：领结',
  3: '徽章：新手饲养员',
  4: '幼年形态（蛋壳褪去）',
  5: '徽章：成长日记家',
  6: '背景：花园',
  7: '配饰：眼镜',
  8: '徽章：宠物达人',
  9: '青年形态',
  10: '徽章：传奇饲养员',
  14: '成年形态',
  15: '徽章：守护之星',
  20: '完全体·可再领养新宠物',
}

// 徽章定义
export const BADGES = {
  first_pet: { name: '初次相遇', desc: '创建你的第一只宠物', icon: '🥚' },
  first_diary: { name: '第一篇日记', desc: '写下第一篇成长日记', icon: '📝' },
  feed_10: { name: '美食家', desc: '喂食宠物 10 次', icon: '🍖' },
  play_10: { name: '玩耍达人', desc: '和宠物玩耍 10 次', icon: '🎾' },
  diary_10: { name: '日记高手', desc: '写下 10 篇日记', icon: '📚' },
  liked_5: { name: '人气宠物', desc: '累计获得 5 个赞', icon: '⭐' },
  level_5: { name: '成长之星', desc: '宠物达到 5 级', icon: '🌟' },
  level_10: { name: '传奇饲养员', desc: '宠物达到 10 级', icon: '👑' },
  level_20: { name: '完全体', desc: '宠物进化到最终形态', icon: '✨' },
} as const

// 状态衰减：每小时衰减 1 点
export const STAT_DECAY_PER_HOUR = 1

// 心情选项
export const MOODS = [
  { value: 'happy', label: '开心', icon: '😊' },
  { value: 'excited', label: '兴奋', icon: '🤩' },
  { value: 'sleepy', label: '困困', icon: '😴' },
  { value: 'playful', label: '调皮', icon: '😜' },
  { value: 'lovely', label: '可爱', icon: '🥰' },
] as const
