import { createClient } from '@supabase/supabase-js'

// Docker serves this path through Nginx on both the domain and IP origins.
// Local development and GitHub Pages keep their direct connection by default.
const proxyPath = import.meta.env.VITE_SUPABASE_PROXY_PATH?.trim()
const supabaseUrl = proxyPath
  ? new URL(proxyPath, window.location.origin).href.replace(/\/$/, '')
  : import.meta.env.VITE_SUPABASE_URL || 'https://ctffjscvkspyqnihvetf.supabase.co'
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'sb_publishable_6Cc1YHvGqR7HZvKqGRMAwA_X4t0Uq9Z'

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
