// TODO: 실제 호출하면서 새로 확인되는 코드가 있으면 여기에 추가
export const ERROR_CODE = {
  LOGIN_FAILED: 'LOGIN_FAILED',
  FORBIDDEN: 'FORBIDDEN',
  OAUTH_FAILED: 'OAUTH_FAILED',
  INVALID_REQUEST: 'INVALID_REQUEST',
  INVALID_INPUT: 'INVALID_INPUT',
  UNAUTHORIZED: 'UNAUTHORIZED',
  TOKEN_EXPIRED: 'TOKEN_EXPIRED',
} as const

export type ErrorCode = (typeof ERROR_CODE)[keyof typeof ERROR_CODE]

// POST /api/v1/auth/login 401 응답 실측 기준
export type ErrorResponse = {
  success: false
  code: ErrorCode
  message: string
  data: null
  retriable: boolean
  timestamp: string
}
