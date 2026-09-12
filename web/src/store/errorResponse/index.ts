import { create } from 'zustand'
import type { ErrorCode, ErrorResponse } from '@/types/error'

type ErrorResponseObject = {
  response: ErrorResponse
  url: string
  method?: string
}

type ErrorResponseState = {
  errorResponses: Partial<Record<ErrorCode, ErrorResponseObject[]>>
  setErrorResponse: (url: string, method: string | undefined, response: ErrorResponse) => void
  clearErrorResponse: (url: string, method: string | undefined, code: ErrorCode) => void
  clear: () => void
}

// 같은 (url, method) 항목만 최신으로 교체, 다른 요청은 코드별 배열에 함께 유지
export const useErrorResponseStore = create<ErrorResponseState>((set) => ({
  errorResponses: {},
  setErrorResponse: (url, method, response) =>
    set((state) => {
      const existing = state.errorResponses[response.code] ?? []
      const next = existing.filter((item) => !(item.url === url && item.method === method))
      next.push({ response, url, method })

      return {
        errorResponses: {
          ...state.errorResponses,
          [response.code]: next,
        },
      }
    }),
  clearErrorResponse: (url, method, code) =>
    set((state) => {
      const existing = state.errorResponses[code]
      if (!existing) return state

      return {
        errorResponses: {
          ...state.errorResponses,
          [code]: existing.filter((item) => !(item.url === url && item.method === method)),
        },
      }
    }),
  clear: () => set({ errorResponses: {} }),
}))
