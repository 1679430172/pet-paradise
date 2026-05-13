<template>
  <div class="page">
    <h1 class="page-title">写日记</h1>

    <form class="editor-form" @submit.prevent="handleSubmit">
      <div class="form-group">
        <label class="form-label">标题</label>
        <input v-model="title" type="text" class="form-input" placeholder="今天发生了什么？" required />
      </div>

      <div class="form-group">
        <label class="form-label">内容</label>
        <textarea v-model="content" class="form-input form-textarea" placeholder="记录宠物的趣事..." rows="5" required></textarea>
      </div>

      <div class="form-group">
        <label class="form-label">心情</label>
        <div class="mood-grid">
          <div
            v-for="m in MOODS"
            :key="m.value"
            class="mood-item"
            :class="{ selected: mood === m.value }"
            @click="mood = m.value"
          >
            <span>{{ m.icon }}</span>
            <span class="mood-label">{{ m.label }}</span>
          </div>
        </div>
      </div>

      <div class="form-group">
        <label class="form-label">添加照片（可选）</label>
        <div class="image-upload" @click="fileInput?.click()">
          <img v-if="previewUrl" :src="previewUrl" class="upload-preview" alt="" />
          <div v-else class="upload-placeholder">
            <span>📷</span>
            <span>点击上传照片</span>
          </div>
        </div>
        <input ref="fileInput" type="file" accept="image/*" hidden @change="handleFileChange" />
      </div>

      <div class="form-group">
        <label class="form-check">
          <input v-model="isPublic" type="checkbox" />
          <span>发布到班级广场</span>
        </label>
      </div>

      <button type="submit" class="btn btn-primary submit-btn" :disabled="submitting">
        {{ submitting ? '发布中...' : '发布日记' }}
      </button>
    </form>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useDiaryStore } from '../stores/diary'
import { MOODS } from '../lib/constants'

const router = useRouter()
const diaryStore = useDiaryStore()

const title = ref('')
const content = ref('')
const mood = ref('happy')
const isPublic = ref(true)
const file = ref<File | null>(null)
const previewUrl = ref('')
const fileInput = ref<HTMLInputElement | null>(null)
const submitting = ref(false)

function handleFileChange(e: Event) {
  const input = e.target as HTMLInputElement
  if (input.files?.[0]) {
    file.value = input.files[0]
    previewUrl.value = URL.createObjectURL(input.files[0])
  }
}

async function handleSubmit() {
  submitting.value = true
  let imageUrl: string | null = null

  if (file.value) {
    imageUrl = await diaryStore.uploadImage(file.value)
  }

  await diaryStore.createEntry({
    title: title.value,
    content: content.value,
    mood: mood.value,
    image_url: imageUrl,
    is_public: isPublic.value,
  })

  submitting.value = false
  router.push('/diary')
}
</script>

<style scoped>
.editor-form {
  display: flex;
  flex-direction: column;
}

.form-textarea {
  resize: vertical;
  min-height: 120px;
}

.mood-grid {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.mood-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 10px 14px;
  background: white;
  border: 2px solid var(--color-border);
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: all 0.2s;
}

.mood-item.selected {
  border-color: var(--color-primary);
  background: #FFF0F5;
}

.mood-item span:first-child {
  font-size: 1.5rem;
}

.mood-label {
  font-size: 0.7rem;
  color: var(--color-text-muted);
}

.image-upload {
  border: 2px dashed var(--color-border);
  border-radius: var(--radius);
  padding: 24px;
  text-align: center;
  cursor: pointer;
  transition: border-color 0.2s;
}

.image-upload:hover {
  border-color: var(--color-primary);
}

.upload-placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  color: var(--color-text-muted);
}

.upload-placeholder span:first-child {
  font-size: 2rem;
}

.upload-preview {
  max-width: 100%;
  max-height: 200px;
  border-radius: var(--radius-sm);
}

.form-check {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  font-size: 0.9rem;
}

.form-check input {
  width: 18px;
  height: 18px;
  accent-color: var(--color-primary);
}

.submit-btn {
  width: 100%;
  padding: 14px;
  font-size: 1rem;
  margin-top: 8px;
}
</style>
