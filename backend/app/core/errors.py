class AppError(Exception):
    code = "INTERNAL_ERROR"
    http_status = 500
    retriable = False

    def __init__(self, message: str = "", detail: str = ""):
        super().__init__(message or self.code)
        self.message = message or self.code
        self.detail = detail


class UpstreamTimeout(AppError):
    code = "UPSTREAM_TIMEOUT"
    http_status = 504
    retriable = True


class UpstreamError(AppError):
    code = "UPSTREAM_ERROR"
    http_status = 502
    retriable = True


class UpstreamMalformed(AppError):
    code = "UPSTREAM_MALFORMED"
    http_status = 502
    retriable = False


class QuotaExceeded(AppError):
    code = "UPSTREAM_QUOTA_EXCEEDED"
    http_status = 503
    retriable = False


class BudgetExceeded(AppError):
    code = "UPSTREAM_BUDGET_EXCEEDED"
    http_status = 200
    retriable = False


class NotFound(AppError):
    code = "NOT_FOUND"
    http_status = 404
