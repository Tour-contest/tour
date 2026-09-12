// TODO: API 연동 명세서의 실제 에러 코드 목록이 확정되면 채운다
export const ERROR_CODE = {
  VALIDATION_FAILED: 'VALIDATION_FAILED',
} as const

export type ErrorCode = (typeof ERROR_CODE)[keyof typeof ERROR_CODE]

// TODO: 백엔드 에러 응답 스키마 확정되면 필드 맞춘다
export type ErrorResponse = {
  code: ErrorCode
  message: string
}
