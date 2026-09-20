import type { AxiosError, AxiosInstance, InternalAxiosRequestConfig } from 'axios'
import { axiosInstance } from '../axiosInstance'

type RetryableConfig = InternalAxiosRequestConfig & { _rateLimitRetry?: number }

// 서버 호출 제한: 로그인 60회/분 (초과 시 429 + Retry-After). 상세 페이지처럼 요청이 몰리면 목록 · 내 정보가 같이 막힌다.
// 조회(GET)만 Retry-After 만큼 기다렸다 다시 보낸다 — 쓰기 요청은 두 번 나가면 안 되므로 그대로 실패시킨다
const MAX_RETRIES = 2
const DEFAULT_WAIT_MS = 1_000
// 이보다 오래 기다리라고 하면 화면을 붙잡아 두는 게 더 나쁘다 — 재시도하지 않고 바로 실패로 넘긴다
const MAX_WAIT_MS = 10_000

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

// Retry-After 는 초(정수) 또는 HTTP 날짜. 못 읽으면 기본값
export const parseRetryAfterMs = (value: unknown, now: number = Date.now()): number => {
  if (typeof value !== 'string' || value.trim() === '') return DEFAULT_WAIT_MS

  const seconds = Number(value)
  if (Number.isFinite(seconds)) return Math.max(seconds * 1000, 0)

  const date = Date.parse(value)
  return Number.isNaN(date) ? DEFAULT_WAIT_MS : Math.max(date - now, 0)
}

const rateLimit = (instance: AxiosInstance) => {
  if (!instance) return

  instance.interceptors.response.use(
    (response) => response,
    async (error: AxiosError) => {
      const original = error.config as RetryableConfig | undefined

      if (error.response?.status !== 429 || !original) return Promise.reject(error)
      if ((original.method ?? 'get').toLowerCase() !== 'get') return Promise.reject(error)

      const retryCount = original._rateLimitRetry ?? 0
      if (retryCount >= MAX_RETRIES) return Promise.reject(error)

      const waitMs = parseRetryAfterMs(error.response.headers?.['retry-after'])
      if (waitMs > MAX_WAIT_MS) return Promise.reject(error)

      original._rateLimitRetry = retryCount + 1
      await sleep(waitMs)
      return axiosInstance(original)
    },
  )
}

export default rateLimit
