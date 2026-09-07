export function petControlTheme(species: string) {
  if (/兔/.test(species)) return { kind: 'rabbit', ink: '#ab587d', tint: '#f3c8d7', light: '#ffe9df' }
  if (/龟/.test(species)) return { kind: 'shell', ink: '#477c61', tint: '#c4dfc3', light: '#edf3d4' }
  if (/孔雀|凤凰/.test(species)) return { kind: 'feather', ink: '#3e7e86', tint: '#bfe1df', light: '#e4f2da' }
  if (/鲤|鱼/.test(species)) return { kind: 'fish', ink: '#ad6347', tint: '#f4c8ad', light: '#fff0d6' }
  if (/松鼠|仓鼠/.test(species)) return { kind: 'nut', ink: '#926638', tint: '#e9d0a9', light: '#fff0d3' }
  if (/龙/.test(species)) return { kind: 'flame', ink: '#8561aa', tint: '#d9c9ed', light: '#f5e5ee' }
  return { kind: 'paw', ink: '#a7587d', tint: '#edc4d7', light: '#ffe9df' }
}

export function petControlStyle(species: string) {
  const theme = petControlTheme(species)
  return { '--pet-control-ink': theme.ink, '--pet-control-tint': theme.tint, '--pet-control-light': theme.light }
}
