// 保留数据库中的原始颜色，只统一展示方式；普通页、大屏和领养预览共用。
export function getPetThemeStyle(color = '#c9ddd4', selected = false) {
  return {
    '--pet-tone': color,
    background: `linear-gradient(160deg, color-mix(in srgb, ${color} ${selected ? 30 : 23}%, white), ${selected ? '#f8fcf9' : '#fff'} 78%)`,
  }
}

export const PET_COLOR_NAMES = ['樱花粉', '晴空蓝', '薄荷绿', '丁香紫', '奶油黄', '蜜桃橙']
