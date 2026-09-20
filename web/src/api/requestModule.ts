import type { AxiosRequestConfig, AxiosResponse } from 'axios'
import { axiosInstance } from './axiosInstance'

type ApiRequestOptions = AxiosRequestConfig & {
  params?: Record<string, unknown>
  data?: Record<string, unknown>
}

export const requestModule = {
  get: async <T = unknown>(url: string, params?: Record<string, unknown>, options?: ApiRequestOptions): Promise<T> => {
    const response: AxiosResponse<T> = await axiosInstance.get(url, { params, ...options })
    return response.data
  },
  post: async <T = unknown>(url: string, data?: Record<string, unknown>, options?: ApiRequestOptions): Promise<T> => {
    const response: AxiosResponse<T> = await axiosInstance.post(url, data, options)
    return response.data
  },
  put: async <T = unknown>(url: string, data?: Record<string, unknown>, options?: ApiRequestOptions): Promise<T> => {
    const response: AxiosResponse<T> = await axiosInstance.put(url, data, options)
    return response.data
  },
  patch: async <T = unknown>(url: string, data?: Record<string, unknown>, options?: ApiRequestOptions): Promise<T> => {
    const response: AxiosResponse<T> = await axiosInstance.patch(url, data, options)
    return response.data
  },
  delete: async <T = unknown>(url: string, params?: Record<string, unknown>, options?: ApiRequestOptions): Promise<T> => {
    const response: AxiosResponse<T> = await axiosInstance.delete(url, { params, ...options })
    return response.data
  },
}
