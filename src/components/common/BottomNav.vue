<template>
  <nav class="bottom-nav">
    <router-link to="/" :class="{ active: route.name === 'home' }">
      <span class="nav-icon">🏠</span>
      <span>宠物</span>
    </router-link>
    <router-link to="/checkins" :class="{ active: route.name === 'photo-checkins' }">
      <span class="nav-icon">📷</span>
      <span>打卡</span>
    </router-link>
    <router-link to="/diary" :class="{ active: route.name === 'diary' || route.name === 'diary-new' }">
      <span class="nav-icon">📖</span>
      <span>日记</span>
    </router-link>
    <router-link to="/feed" :class="{ active: route.name === 'feed' }">
      <span class="nav-icon">🌍</span>
      <span>广场</span>
    </router-link>
    <router-link to="/shop" :class="{ active: route.name === 'shop' }">
      <span class="nav-icon">🛒</span>
      <span>商城</span>
    </router-link>
    <router-link to="/travel" :class="{ active: route.name === 'travel' }">
      <span class="nav-icon">🧳</span>
      <span>旅行</span>
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
