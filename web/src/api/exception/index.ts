import authenticate from './authenticate'
import badRequest from './badRequest'
import rateLimit from './rateLimit'

// 그 외 상태 코드는 필요해지는 시점에 파일을 추가하고 여기서 등록한다
export { authenticate, badRequest, rateLimit }
