import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PayuCheckoutWebView extends StatefulWidget {
  final String actionUrl;
  final Map<String, dynamic> params;

  const PayuCheckoutWebView(
      {super.key, required this.actionUrl, required this.params});

  @override
  State<PayuCheckoutWebView> createState() => _PayuCheckoutWebViewState();
}

class _PayuCheckoutWebViewState extends State<PayuCheckoutWebView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (NavigationRequest req) async {
          final url = req.url;
          final uri = Uri.tryParse(url);
          // Upgrade PayU cleartext callback URLs to HTTPS to avoid ERR_CLEARTEXT_NOT_PERMITTED
          if (uri != null &&
              uri.scheme == 'http' &&
              (uri.host.contains('payu') || uri.host.contains('payubiz'))) {
            final httpsUri = uri.replace(scheme: 'https');
            _controller.loadRequest(httpsUri);
            return NavigationDecision.prevent;
          }
          if (uri != null && uri.scheme != 'http' && uri.scheme != 'https') {
            // Handle UPI deep links and other non-http(s)
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            // Handle intent:// fallback URLs from Chrome
            if (url.startsWith('intent://')) {
              try {
                final intentUrl = url.replaceFirst('intent://', '');
                final schemeEnd = intentUrl.indexOf('#Intent');
                final actual = schemeEnd > 0
                    ? intentUrl.substring(0, schemeEnd)
                    : intentUrl;
                final actualUri = Uri.tryParse(actual);
                if (actualUri != null && await canLaunchUrl(actualUri)) {
                  await launchUrl(actualUri,
                      mode: LaunchMode.externalApplication);
                  return NavigationDecision.prevent;
                }
              } catch (_) {}
            }
          }
          return NavigationDecision.navigate;
        },
        onPageFinished: (_) => setState(() => _loading = false),
      ));

    final formInputs = widget.params.entries.map((e) {
      final k = e.key;
      final v = (e.value ?? '').toString().replaceAll("'", "&#39;");
      return "<input type='hidden' name='${k}' value='${v}'/>";
    }).join();

    final html = """
<!DOCTYPE html><html><body>
  <form id='payuForm' method='post' action='${widget.actionUrl}'>
    ${formInputs}
  </form>
  <script>document.getElementById('payuForm').submit();</script>
</body></html>
""";

    _controller.loadHtmlString(html);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Processing Payment')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
