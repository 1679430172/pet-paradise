import { supabase } from './supabase'

export interface PhotoCheckin {
  id: string; student_id: string | null; student_name: string; class_name: string | null
  description: string; status: 'pending' | 'awarded' | 'rejected' | 'expired'
  points: number; feedback: string; submitted_at: string; expires_at: string
  photo_deleted_at: string | null; image_url: string | null; image_error: boolean; revoked: boolean
}
export interface CheckinList {
  entries: PhotoCheckin[]; total: number; todayCount: number; urgentCount: number
  students: { id: string; username: string; class_name: string | null }[]
}
export const sessionKey = (id: string) => `photo_checkin_session:${id}`
export const sessionErrorKey = (id: string) => `photo_checkin_error:${id}`
export const checkinToken = (id: string) => localStorage.getItem(sessionKey(id)) || sessionStorage.getItem(sessionKey(id)) || ''

export async function establishCheckinSession(profileId: string, password: string): Promise<string | null> {
  localStorage.removeItem(sessionErrorKey(profileId))
  localStorage.removeItem(sessionKey(profileId))
  sessionStorage.removeItem(sessionKey(profileId))
  try {
    const result = await checkinApi<{ token: string; expires: string }>(profileId, 'login', { profileId, password })
    localStorage.setItem(sessionKey(profileId), result.token)
    return result.expires
  } catch (error) {
    // 打卡服务尚未部署时，保留原有网站登录，不阻断其他功能。
    localStorage.setItem(sessionErrorKey(profileId), error instanceof Error ? error.message : '打卡服务暂不可用')
    return null
  }
}

export async function checkinApi<T>(profileId: string, action: string, args: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await supabase.functions.invoke('photo-checkins', {
    body: { ...args, action },
    headers: { 'x-checkin-token': checkinToken(profileId) },
  })
  if (error) {
    const response = (error as { context?: Response }).context
    if (response?.status === 401) {
      sessionStorage.removeItem(sessionKey(profileId))
      localStorage.removeItem(sessionKey(profileId))
    }
    const result = response instanceof Response ? await response.json().catch(() => null) : null
    if (response?.status === 404 && result?.code === 'NOT_FOUND') {
      throw new Error('打卡服务尚未上线，请联系管理员启用后再试')
    }
    throw new Error(result?.error || result?.message || '暂时无法连接打卡服务，请稍后重试')
  }
  if (data?.error) throw new Error(data.error)
  return data as T
}

// Canvas 重编码去除 EXIF 等原始元数据；只上传压缩结果。
export async function compressCheckinPhoto(file: File): Promise<Blob> {
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) throw new Error('请选择 JPG、PNG 或 WebP 照片；HEIC 请先转成 JPG')
  if (file.size > 20 * 1024 * 1024) throw new Error('原照片不能超过 20 MB')
  const url = URL.createObjectURL(file)
  try {
    const img = new Image(); img.src = url
    await img.decode().catch(() => { throw new Error('无法读取照片，请换一张重试') })
    let longest = Math.min(1600, Math.max(img.naturalWidth, img.naturalHeight))
    for (let attempt = 0; attempt < 6; attempt++) {
      const scale = longest / Math.max(img.naturalWidth, img.naturalHeight)
      const canvas = document.createElement('canvas')
      canvas.width = Math.max(1, Math.round(img.naturalWidth * scale))
      canvas.height = Math.max(1, Math.round(img.naturalHeight * scale))
      const ctx = canvas.getContext('2d')
      if (!ctx) throw new Error('当前浏览器不支持照片处理')
      ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, canvas.width, canvas.height)
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
      for (const quality of [0.82, 0.68, 0.52]) {
        const blob = await new Promise<Blob | null>(resolve => canvas.toBlob(resolve, 'image/jpeg', quality))
        if (blob && blob.size <= 200 * 1024) return blob
      }
      longest *= 0.75
    }
    throw new Error('照片压缩失败，请换一张照片')
  } finally { URL.revokeObjectURL(url) }
}

export function photoBase64(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(String(reader.result).split(',')[1] || '')
    reader.onerror = () => reject(new Error('照片读取失败'))
    reader.readAsDataURL(blob)
  })
}
