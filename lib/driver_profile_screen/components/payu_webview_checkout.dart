import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'package:okdriver/home_screen/homescreen.dart';
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
  bool _paymentSuccessHandled = false;
  Timer? _redirectTimer;

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
          // Detect success keywords in URL and handle success
          if (_looksLikeSuccessUrl(url)) {
            _handlePaymentSuccess();
          }
          return NavigationDecision.navigate;
        },
        onPageFinished: (_) async {
          setState(() => _loading = false);
          final url = await _controller.currentUrl();
          if (url != null && _looksLikeSuccessUrl(url)) {
            _handlePaymentSuccess();
          }
        },
        onWebResourceError: (WebResourceError error) {
          // Some gateways redirect to non-https callback causing failures; avoid showing error page
          // We keep the webview silent and rely on URL-based success detection or backend update
        },
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

  bool _looksLikeSuccessUrl(String url) {
    final lower = url.toLowerCase();
    // Common PayU success indicators; adjust as needed for backend callback routes
    return lower.contains('status=success') ||
        lower.contains('payment/success') ||
        lower.contains('success=true') ||
        lower.contains('payu') && lower.contains('success') ||
        lower.contains('txnstatus=success') ||
        lower.contains('result=success') ||
        lower.contains('payment_status=success') ||
        lower.contains('20.204.177.196') &&
            (lower.contains('success') || lower.contains('completed')) ||
        lower.contains('return') && lower.contains('success');
  }

  void _handlePaymentSuccess() {
    if (_paymentSuccessHandled) return;
    _paymentSuccessHandled = true;

    if (mounted) {
      // Show success dialog instead of snackbar for better visibility
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.green.shade50,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Payment Successful!',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: const Text(
            'Your payment has been processed successfully. You will be redirected to home screen in 5 seconds.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                'Go to Home',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    _redirectTimer?.cancel();
    _redirectTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close dialog if still open
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Processing Payment')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
          if (_paymentSuccessHandled)
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 4),
                child: LinearProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }
}
