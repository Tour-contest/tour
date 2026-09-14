import type { AxiosError, AxiosInstance, InternalAxiosRequestConfig } from 'axios'
import { axiosInstance } from '../axiosInstance'
import { requestRefresh, applyRefreshedToken, clearSession } from '../tokenManager'
import { useErrorResponseStore } from '@/store/errorResponse'
import type { ErrorResponse } from '@/types/error'

type RetryableConfig = InternalAxiosRequestConfig & { _retry?: boolean }

// 로그인 자체의 401 은 "갱신할 세션이 없는" 상태라 refresh 대상이 아니다 (화면에 보여줄 에러)
const AUTH_ENTRY_PATHS = ['/auth/login', '/auth/dev-login', '/auth/oauth/']

// 선제 검사로 못 잡는 케이스(서버 강제 무효화, 시계 오차)를 위한 안전망
const authenticate = (instance: AxiosInstance) => {
  if (!instance) return

  instance.interceptors.response.use(
    (response) => response,
    async (error: AxiosError) => {
      const original = error.config as RetryableConfig | undefined

      if (error.response?.status !== 401) return Promise.reject(error)

      const url = original?.url ?? ''

      if (url.includes('/auth/refresh')) {
        clearSession()
        return Promise.reject(error)
      }

      if (AUTH_ENTRY_PATHS.some((path) => url.includes(path))) {
        useErrorResponseStore
          .getState()
          .setErrorResponse(url, original?.method, error.response.data as ErrorResponse)
        return Promise.reject(error)
      }

      if (original && !original._retry) {
        original._retry = true

        try {
          const res = await requestRefresh()

          if (res.success) {
            applyRefreshedToken(res.data)
            original.headers.Authorization = `Bearer ${res.data.access_token}`
            return axiosInstance(original)
          }
        } catch (refreshError) {
          console.error(refreshError)
        }

        clearSession()
      }

      return Promise.reject(error)
    },
  )
}

export default authenticate
