// 宠物种类（数组开放扩展，新增宠物只需：
// 1) 在此数组追加 species key（与 public/assets/pets/{key} 文件夹名一致）
// 2) 在 PET_SPECIES_LABELS 添加对应展示名
// 3) 准备 public/assets/pets/{key}/Stage_{stage}.png 共 5 张阶段图片
// 4) 可选：在各页面 speciesIcons / PetAvatar SPECIES_EMOJI 添加 emoji 图标
// 当前仅有「紫电龙」一个种类的素材，但架构支持任意多种）
export const PET_SPECIES = [
  '紫电龙', '星焰狐', '云朵猫', '碧海龟',
  '小狗', '小兔子', '小羊', '熊猫', '龙', '孔雀', '牛', '马',
  '凤凰', '仓鼠', '锦鲤', '猴子', '老虎', '猪', '考拉', '松鼠',
] as const
export type PetSpecies = typeof PET_SPECIES[number]

export const PET_SPECIES_LABELS: Record<PetSpecies, string> = {
  紫电龙: '紫电龙',
  星焰狐: '星焰狐',
  云朵猫: '云朵猫',
  碧海龟: '碧海龟',
  小狗: '阳光旺旺',
  小兔子: '月光兔兔',
  小羊: '彩云绵绵',
  熊猫: '竹叶团团',
  龙: '蓝云萌龙',
  孔雀: '彩羽雀雀',
  牛: '花铃牛牛',
  马: '星梦小马',
  凤凰: '暖羽凰凰',
  仓鼠: '金豆仓仓',
  锦鲤: '锦云泡泡',
  猴子: '桃桃灵猴',
  老虎: '雪团虎宝',
  猪: '福气圆圆',
  考拉: '桉叶困困',
  松鼠: '果果松鼠',
}

// 宠物颜色
export const PET_COLORS: string[] = ['#FFB6C1', '#87CEEB', '#98FB98', '#DDA0DD', '#F0E68C', '#FFA07A']

// 动作配置：三档喂食，统一作用于 hunger
export const ACTIONS = {
  basic: { xp: 8, statKey: 'hunger' as const, statGain: 25, label: '普通粮', icon: '🍖' },
  nice: { xp: 18, statKey: 'hunger' as const, statGain: 55, label: '营养粮', icon: '🍗' },
  luxury: { xp: 40, statKey: 'hunger' as const, statGain: 100, label: '豪华粮', icon: '🥩' },
} as const

const FEEDING_REPLIES = {
  basic: ['谢谢你，我吃饱一点啦！', '普通粮也很香，谢谢！', '嗷呜，好吃！'],
  nice: ['营养餐真不错，我更有精神了！', '好香呀，我很喜欢！', '吃得好满足，谢谢你！'],
  luxury: ['哇，是豪华大餐！太幸福啦！', '这是我吃过最好吃的！', '大餐时间，我要全部吃光！'],
} as const

export function getFeedingReply(action: keyof typeof FEEDING_REPLIES): string {
  const replies = FEEDING_REPLIES[action]
  return replies[Math.floor(Math.random() * replies.length)]
}

export type ActionKey = keyof typeof ACTIONS

// 默认积分消耗配置
export const DEFAULT_ACTION_COSTS = { basic: 5, nice: 10, luxury: 20 }

// 日记、图片和点赞暂不参与宠物成长，保留常量便于后续重新启用。
export const DIARY_XP = 0
export const PHOTO_XP = 0
export const LIKE_XP = 0

// 等级上限
export const MAX_LEVEL = 20

// 等级经验值表（1..20）
export const LEVEL_THRESHOLDS = [
  0,     // Level 1
  20,    // Level 2  (+20)
  50,    // Level 3  (+30)
  90,    // Level 4  (+40)
  140,   // Level 5  (+50)
  200,   // Level 6  (+60)
  275,   // Level 7  (+75)
  365,   // Level 8  (+90)
  470,   // Level 9  (+105)
  590,   // Level 10 (+120)
  730,   // Level 11 (+140)
  890,   // Level 12 (+160)
  1070,  // Level 13 (+180)
  1270,  // Level 14 (+200)
  1495,  // Level 15 (+225)
  1745,  // Level 16 (+250)
  2025,  // Level 17 (+280)
  2335,  // Level 18 (+310)
  2675,  // Level 19 (+340)
  3050,  // Level 20 (+375)
]

// 形态阶段：Lv.1-3 蛋 / Lv.4-8 幼年（蛋壳逐渐破裂）/ Lv.9-13 青年 / Lv.14-19 成年 / Lv.20 完全体
export const PET_STAGES = ['egg', 'baby', 'teen', 'adult', 'final'] as const
export type PetStage = typeof PET_STAGES[number]

// public 目录下的素材不会经过 Vite 文件名哈希；更新此值可避免 CDN/浏览器继续使用旧图。
const PET_ASSET_VERSION = '20260904-complete'

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

// 静态图片按成长阶段复用，避免为 20 个等级保存重复文件。
// 文件路径：/assets/pets/{species}/Stage_{egg|baby|teen|adult|final}.png
export function getPetImage(species: string, level: number): string {
  // 未登记的种类（如旧数据库中的历史 species 值）回退到 PET_SPECIES[0]
  // 这样后续新增种类时不需要修改 fallback 逻辑
  const sp = (PET_SPECIES as readonly string[]).includes(species) ? species : PET_SPECIES[0]
  return `${import.meta.env.BASE_URL}assets/pets/${encodeURIComponent(sp)}/Stage_${getPetStage(level)}.png?v=${PET_ASSET_VERSION}`
}

// 动态待机素材按成长阶段复用；静态 PNG 仍作为兼容和减少动态效果时的回退。
export function getPetAnimation(species: string, level: number): string {
  const sp = (PET_SPECIES as readonly string[]).includes(species) ? species : PET_SPECIES[0]
  return `${import.meta.env.BASE_URL}assets/pets/${encodeURIComponent(sp)}/Stage_${getPetStage(level)}.webp?v=${PET_ASSET_VERSION}`
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

// 饱食度每小时衰减 1.5 点，约 67 小时从 100 降至 0。
export const STAT_DECAY_PER_HOUR = 1.5

// 心情选项
export const MOODS = [
  { value: 'happy', label: '开心', icon: '😊' },
  { value: 'excited', label: '兴奋', icon: '🤩' },
  { value: 'sleepy', label: '困困', icon: '😴' },
  { value: 'playful', label: '调皮', icon: '😜' },
  { value: 'lovely', label: '可爱', icon: '🥰' },
] as const
