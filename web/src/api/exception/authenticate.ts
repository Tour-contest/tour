import type { AxiosError, AxiosInstance, InternalAxiosRequestConfig } from 'axios'
import { useErrorResponseStore } from '@/store/errorResponse'
import type { ErrorResponse } from '@/types/error'

const authenticate = (instance: AxiosInstance) => {
  if (!instance) return

  instance.interceptors.response.use(
    (response) => response,
    (error: AxiosError) => {
      const original = error.config as InternalAxiosRequestConfig | undefined

      if (error.response?.status === 401) {
        useErrorResponseStore
          .getState()
          .setErrorResponse(original?.url ?? '', original?.method, error.response.data as ErrorResponse)
      }

      return Promise.reject(error)
    },
  )
}

export default authenticate
