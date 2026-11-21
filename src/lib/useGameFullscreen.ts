import { computed, onBeforeUnmount, onMounted, ref, useTemplateRef } from 'vue'

export function useGameFullscreen() {
  const fullscreenTarget = useTemplateRef<HTMLElement>('fullscreenTarget')
  const nativeFullscreen = ref(false)
  const expanded = ref(false)
  const fullscreen = computed(() => nativeFullscreen.value || expanded.value)
  const fullscreenLabel = computed(() => fullscreen.value ? '退出全屏' : '全屏')

  function syncFullscreen() {
    nativeFullscreen.value = document.fullscreenElement === fullscreenTarget.value
  }

  async function toggleFullscreen() {
    const target = fullscreenTarget.value
    if (!target) return
    if (expanded.value) {
      expanded.value = false
      return
    }
    if (document.fullscreenElement === target) {
      await document.exitFullscreen().catch(() => {})
      return
    }
    try {
      if (target.requestFullscreen) {
        await target.requestFullscreen()
        syncFullscreen()
        return
      }
    } catch {
      // Some browsers and embedded pages only support expanding inside the viewport.
    }
    if (fullscreenTarget.value === target) expanded.value = true
  }

  function exitExpanded(event: KeyboardEvent) {
    if (event.key === 'Escape' && expanded.value) {
      event.preventDefault()
      expanded.value = false
    }
  }

  onMounted(() => {
    document.addEventListener('fullscreenchange', syncFullscreen)
    document.addEventListener('keydown', exitExpanded)
  })
  onBeforeUnmount(() => {
    document.removeEventListener('fullscreenchange', syncFullscreen)
    document.removeEventListener('keydown', exitExpanded)
    if (document.fullscreenElement === fullscreenTarget.value) {
      void document.exitFullscreen().catch(() => {})
    }
  })

  return { fullscreen, fullscreenLabel, toggleFullscreen }
}
