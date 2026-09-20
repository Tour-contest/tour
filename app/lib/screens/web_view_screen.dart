import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nullnull/app_log.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/nullnull/plain_header.dart';

/// [WebViewScreen]을 `context.pushNamed(RouteNames.webView, extra: ...)`로
/// 열 때 넘기는 인자. `chat_screen.dart`의 `ChatResumeData`와 동일한 패턴.
class WebViewRouteArgs {
  const WebViewRouteArgs({required this.title, required this.url});

  final String title;
  final String url;
}

/// `title`/`url`만 받아 [InAppWebView]를 꽉 채워 그리는 범용 웹뷰 화면.
/// 개인정보처리방침/서비스 이용약관처럼 외부 URL을 앱 안에서 그대로
/// 보여줘야 하는 화면에서 재사용한다(`docs/PRIVACY.md`/`docs/TERMS_OF_SERVICE.md`
/// 참고).
class WebViewScreen extends StatefulWidget {
  final String title;
  final String url;

  const WebViewScreen({super.key, required this.title, required this.url});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _controller;

  /// 메인 프레임 로딩이 실패했을 때만 켠다(하위 리소스 실패로 전체 화면을
  /// 덮지 않도록 `onReceivedError`/`onReceivedHttpError`에서
  /// `request.isForMainFrame`을 확인한다). 켜지면 [InAppWebView] 위에
  /// [_WebViewErrorState]를 겹쳐 그린다 — 위젯을 통째로 갈아치우지 않고
  /// 겹쳐 그리는 이유는 [_controller]를 그대로 살려둬 재시도 시 새로
  /// 만들지 않고 `reload()`만 호출할 수 있게 하기 위해서다.
  bool _hasError = false;

  /// `shouldOverrideUrlLoading`을 받으려면 이 설정이 필요하다(패키지 문서
  /// 참고).
  final InAppWebViewSettings _settings = InAppWebViewSettings(
    useShouldOverrideUrlLoading: true,
  );

  void _handleLoadFailure(WebResourceRequest request) {
    if (!(request.isForMainFrame ?? true)) return;
    if (mounted) setState(() => _hasError = true);
  }

  void _retry() {
    setState(() => _hasError = false);
    _controller?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          maintainBottomViewPadding: true,
          child: Column(
            children: [
              PlainHeader(title: widget.title),
              Expanded(
                child: Stack(
                  children: [
                    InAppWebView(
                      initialSettings: _settings,
                      initialUrlRequest: URLRequest(
                        url: WebUri(widget.url),
                      ),
                      onWebViewCreated: (ctl) {
                        AppLog.logger.d('onWebViewCreated');
                        _controller = ctl;
                      },
                      onLoadStart: (controller, url) {
                        if (mounted) setState(() => _hasError = false);
                      },
                      // 페이지 안의 `tel:`/`mailto:` 같은 앱 스킴 링크는
                      // 웹뷰가 직접 못 열므로 기기의 기본 앱으로 밖에서
                      // 열고, 웹뷰 안에서는 그 네비게이션을 취소한다.
                      // http(s)는 그대로 웹뷰 안에서 이어서 로드한다.
                      shouldOverrideUrlLoading: (controller, action) async {
                        final uri = action.request.url;
                        if (uri == null) {
                          return NavigationActionPolicy.ALLOW;
                        }
                        final scheme = uri.scheme.toLowerCase();
                        if (scheme == 'http' || scheme == 'https') {
                          return NavigationActionPolicy.ALLOW;
                        }
                        final launchUri = Uri.parse(uri.toString());
                        try {
                          if (await canLaunchUrl(launchUri)) {
                            await launchUrl(launchUri);
                          }
                        } catch (error) {
                          AppLog.logger.e('외부 스킴 실행 실패: $uri', error: error);
                        }
                        return NavigationActionPolicy.CANCEL;
                      },
                      // 이 화면엔 카메라/마이크 접근이 필요한 콘텐츠가 없어
                      // 항상 거부한다(명시하지 않아도 기본값이 DENY지만,
                      // 방치된 콜백이라 의도를 분명히 남겨둠).
                      onPermissionRequest: (controller, request) async {
                        return PermissionResponse(
                          resources: request.resources,
                          action: PermissionResponseAction.DENY,
                        );
                      },
                      onReceivedError: (controller, request, error) {
                        AppLog.logger.e(error.toString());
                        _handleLoadFailure(request);
                      },
                      onReceivedHttpError:
                          (controller, request, errorResponse) {
                        AppLog.logger.e(errorResponse.toString());
                        _handleLoadFailure(request);
                      },
                    ),
                    if (_hasError) _WebViewErrorState(onRetry: _retry),
                  ],
                ),
              ),
            ],
          )),
    );
  }
}

/// 웹뷰 메인 프레임 로딩 실패 시 [InAppWebView] 위에 겹쳐 그리는 에러 안내.
/// `attraction_detail_screen.dart`의 `_MessageState`와 같은 시각 패턴(안내
/// 문구 + 재시도 버튼, `l10n.historyRetryButton` 재사용)을 따른다.
class _WebViewErrorState extends StatelessWidget {
  const _WebViewErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Positioned.fill(
      child: ColoredBox(
        color: colors.paper,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.webViewLoadError,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(color: colors.ink600),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.accent),
                  ),
                  child: Text(
                    l10n.historyRetryButton,
                    style: AppTextStyles.body(color: colors.accentBright),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
