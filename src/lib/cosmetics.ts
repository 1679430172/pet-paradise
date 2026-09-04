import type { CSSProperties } from 'vue'

export type CosmeticCategory = 'frame' | 'background'

export interface CosmeticSelection {
  frame?: string | null
  background?: string | null
}

export function cosmeticClasses(selection?: CosmeticSelection | null) {
  return [
    selection?.frame ? `cosmetic-frame-${selection.frame}` : '',
    selection?.background ? `cosmetic-background-${selection.background}` : '',
  ].filter(Boolean)
}

export function previewThemeStyle(color = '#ff9dbb'): CSSProperties {
  return { '--preview-tone': color } as CSSProperties
}
