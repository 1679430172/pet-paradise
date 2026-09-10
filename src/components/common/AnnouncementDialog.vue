<template>
  <Transition name="announcement-fade">
    <div v-if="visible" class="announcement-overlay" @click.self="dismiss">
      <section class="announcement-dialog" :class="`type-${announcement?.type || 'notice'}`" role="dialog" aria-modal="true" aria-labelledby="announcement-title">
        <div class="announcement-icon" aria-hidden="true">{{ appearance.icon }}</div>
        <span class="announcement-label">{{ appearance.label }}</span>
        <h2 id="announcement-title">{{ announcement?.title }}</h2>
        <div class="announcement-content">{{ announcement?.content }}</div>
        <button type="button" @click="dismiss">我知道了</button>
      </section>
    </div>
  </Transition>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useAuthStore, type AnnouncementSetting } from '../../stores/auth'

const authStore = useAuthStore()
const announcement = ref<AnnouncementSetting | null>(null)
const dismissed = ref(false)
const visible = computed(() => !!authStore.user && !authStore.isAdmin && announcement.value?.enabled === true && !!announcement.value.content && !dismissed.value)
const appearances = {
  notice: { icon: '📣', label: '最新通知' },
  celebration: { icon: '🎉', label: '一起庆祝' },
  reminder: { icon: '⏰', label: '温馨提醒' },
  maintenance: { icon: '🛠️', label: '维护公告' },
  other: { icon: '💬', label: '其他公告' },
} as const
const appearance = computed(() => appearances[announcement.value?.type || 'notice'])

watch(() => authStore.user?.id, async (userId) => {
  announcement.value = null
  dismissed.value = false
  if (!userId || authStore.isAdmin) return
  const result = await authStore.fetchAnnouncement()
  if (result.error || !result.data) return
  announcement.value = result.data
}, { immediate: true })

function dismiss() {
  dismissed.value = true
}
</script>

<style scoped>
.announcement-overlay { position:fixed; inset:0; z-index:1000; display:grid; place-items:center; padding:20px; background:rgba(45,35,54,.48); backdrop-filter:blur(4px); }
.announcement-dialog { --accent:#e96391; --accent-soft:#fff0f5; --surface:#fff9f3; box-sizing:border-box; width:min(440px,100%); padding:30px 28px 24px; border:1px solid color-mix(in srgb,var(--accent) 25%,transparent); border-radius:24px; background:linear-gradient(160deg,#fff 0%,var(--surface) 100%); box-shadow:0 24px 70px rgba(55,38,62,.2); text-align:center; }
.announcement-dialog.type-celebration { --accent:#e99a19; --accent-soft:#fff3cf; --surface:#fffaf0; }
.announcement-dialog.type-reminder { --accent:#7a58d5; --accent-soft:#f0ebff; --surface:#faf8ff; }
.announcement-dialog.type-maintenance { --accent:#287e9c; --accent-soft:#e5f5fa; --surface:#f4fbfd; }
.announcement-dialog.type-other { --accent:#567166; --accent-soft:#eaf2ee; --surface:#f7faf8; }
.announcement-icon { display:grid; place-items:center; width:58px; height:58px; margin:0 auto 12px; border-radius:18px; background:var(--accent-soft); font-size:1.75rem; transform:rotate(-5deg); }
.announcement-label { color:var(--accent); font-size:.72rem; font-weight:800; letter-spacing:.14em; }
h2 { margin:8px 0 14px; color:#3a3040; font-size:1.45rem; }
.announcement-content { max-height:42vh; overflow:auto; color:#655d69; line-height:1.8; text-align:left; white-space:pre-wrap; overflow-wrap:anywhere; }
button { width:100%; margin-top:22px; padding:12px 18px; border:0; border-radius:12px; color:white; background:var(--accent); box-shadow:0 8px 20px color-mix(in srgb,var(--accent) 28%,transparent); cursor:pointer; font-weight:800; }
.announcement-fade-enter-active,.announcement-fade-leave-active { transition:opacity .2s ease; }
.announcement-fade-enter-active .announcement-dialog,.announcement-fade-leave-active .announcement-dialog { transition:transform .2s ease; }
.announcement-fade-enter-from,.announcement-fade-leave-to { opacity:0; }
.announcement-fade-enter-from .announcement-dialog,.announcement-fade-leave-to .announcement-dialog { transform:translateY(10px) scale(.98); }
</style>
