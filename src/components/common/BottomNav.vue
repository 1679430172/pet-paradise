<template>
  <nav class="bottom-nav">
    <router-link to="/" :class="{ active: route.name === 'home' }">
      <span class="nav-icon">🏠</span>
      <span>宠物</span>
    </router-link>
    <router-link to="/diary" :class="{ active: route.name === 'diary' || route.name === 'diary-new' }">
      <span class="nav-icon">📖</span>
      <span>日记</span>
    </router-link>
    <router-link to="/feed" :class="{ active: route.name === 'feed' }">
      <span class="nav-icon">🌍</span>
      <span>广场</span>
    </router-link>
    <router-link to="/profile" :class="{ active: route.name === 'profile' }">
      <span class="nav-icon">👤</span>
      <span>我的</span>
    </router-link>
  </nav>
</template>

<script setup lang="ts">
import { useRoute } from 'vue-router'
const route = useRoute()
</script>
