import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:nullnull/app_log.dart';
import 'package:nullnull/widgets/nullnull/plain_header.dart';

/// ---------------------------------------------------------------------------------------------------
///
/// web_view_screen.dart: 웹뷰 화면
/// url parameter 필요
/// TODO: 에러처리,
///
/// ---------------------------------------------------------------------------------------------------

/// [WebViewScreen]을 `context.pushNamed(RouteNames.webView, extra: ...)`로
/// 열 때 넘기는 인자. `place_detail_screen.dart`의 `PlaceRecommendation`,
/// `chat_screen.dart`의 `ChatResumeData`와 동일한 패턴.
class WebViewRouteArgs {
  const WebViewRouteArgs({required this.title, required this.url});

  final String title;
  final String url;
}

class WebViewScreen extends StatefulWidget {
  final String title;
  final String url;

  const WebViewScreen({super.key, required this.title, required this.url});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? controller;
  InAppWebViewSettings settings = InAppWebViewSettings(
      // javaScriptCanOpenWindowsAutomatically: true,
      // useShouldOverrideUrlLoading: true,
      );

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
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
                child: InAppWebView(
                  initialSettings: settings,
                  initialUrlRequest: URLRequest(
                    url: WebUri(widget.url),
                  ),
                  onWebViewCreated: (ctl) {
                    AppLog.logger.d('onWebViewCreated');
                    controller = ctl;
                  },
                  // onPermissionRequest:(controller, permissionRequest) {
                  //   /// TODO
                  // },
                  // shouldOverrideUrlLoading: (ctl, action) {
                  //   /// TODO
                  // },
                  onReceivedError: (controller, request, error) {
                    /// TODO
                    AppLog.logger.e(error.toString());
                  },
                  onReceivedHttpError: (controller, request, errorResponse) {
                    /// TODO
                    AppLog.logger.e(errorResponse.toString());
                  },
                ),
              ),
            ],
          )),
    );
  }
}
