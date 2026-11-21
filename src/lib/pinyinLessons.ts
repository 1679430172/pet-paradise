type Sound = [pinyin: string, recording: number]
type SoundGroup = { title?: string; sounds: Sound[] }
type Blend =
  | [initial: string, final: string, character: string]
  | [initial: string, medial: string, final: string, character: string]
type Lesson =
  | { title: string; category: string; soundGroups: SoundGroup[] }
  | { title: string; category: string; blends: Blend[] }

export const pinyinLessons: Lesson[] = [
  {
    title: '单韵母', category: '韵母',
    soundGroups: [{ sounds: [['a', 22], ['o', 23], ['e', 24], ['i', 35], ['u', 36], ['ü', 37]] }],
  },
  {
    title: '双唇音和唇齿音', category: '声母',
    soundGroups: [
      { title: '双唇音', sounds: [['b', 1], ['p', 2], ['m', 3]] },
      { title: '唇齿音', sounds: [['f', 4]] },
    ],
  },
  {
    title: '舌尖中音、舌根音和舌面音', category: '声母',
    soundGroups: [
      { title: '舌尖中音', sounds: [['d', 5], ['t', 6], ['n', 7], ['l', 8]] },
      { title: '舌根音', sounds: [['g', 9], ['k', 10], ['h', 11]] },
      { title: '舌面音', sounds: [['j', 12], ['q', 13], ['x', 14]] },
    ],
  },
  {
    title: '翘舌音和平舌音', category: '声母',
    soundGroups: [
      { title: '翘舌音', sounds: [['zh', 15], ['ch', 16], ['sh', 17], ['r', 18]] },
      { title: '平舌音', sounds: [['z', 19], ['c', 20], ['s', 21]] },
    ],
  },
  {
    title: 'y、w', category: '隔音字母',
    soundGroups: [{ sounds: [['y', 35], ['w', 36]] }],
  },
  {
    title: '复韵母和鼻韵母', category: '韵母选读',
    soundGroups: [
      { title: '复韵母', sounds: [['ai', 26], ['ei', 27], ['ao', 28], ['ou', 29]] },
      { title: '鼻韵母', sounds: [['an', 30], ['en', 31], ['ang', 32], ['eng', 33]] },
    ],
  },
  {
    title: '声母 + 韵母', category: '两拼',
    blends: [
      ['b', 'ā', '八'], ['p', 'á', '爬'], ['m', 'ǎ', '马'], ['f', 'ā', '发'],
      ['d', 'à', '大'], ['t', 'ī', '踢'], ['n', 'á', '拿'], ['l', 'ù', '路'],
      ['g', 'ē', '歌'], ['k', 'āi', '开'], ['h', 'ǎo', '好'], ['m', 'āo', '猫'],
      ['sh', 'ān', '山'], ['m', 'én', '门'], ['f', 'ēng', '风'], ['c', 'ǎo', '草'],
    ],
  },
  {
    title: '声母 + 介母 + 韵母', category: '三拼',
    blends: [
      ['g', 'u', 'ā', '瓜'], ['k', 'u', 'ā', '夸'], ['h', 'u', 'ā', '花'],
      ['d', 'u', 'ǒ', '朵'], ['h', 'u', 'ǒ', '火'], ['g', 'u', 'ǒ', '果'],
      ['j', 'i', 'ā', '家'], ['q', 'i', 'ā', '掐'], ['x', 'i', 'ā', '虾'],
      ['l', 'i', 'ǎng', '两'], ['x', 'i', 'āng', '香'], ['h', 'u', 'áng', '黄'],
      ['zh', 'u', 'ā', '抓'], ['sh', 'u', 'ā', '刷'],
    ],
  },
]
