// Buy Plan Screen
import 'package:flutter/material.dart';
import 'package:okdriver/driver_profile_screen/components/payu_webview_checkout.dart';
import 'package:provider/provider.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// import 'package:okdriver/driver_profile_screen/components/payu_checkout_webview.dart';
import 'package:okdriver/config/api_config.dart';
import 'package:okdriver/service/usersession_service.dart';

class BuyPlanScreen extends StatefulWidget {
  const BuyPlanScreen({super.key});

  @override
  State<BuyPlanScreen> createState() => _BuyPlanScreenState();
}

class _BuyPlanScreenState extends State<BuyPlanScreen> {
  late bool _isDarkMode;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _plans = [];
  int _selectedPlanIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize _isDarkMode from ThemeProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      setState(() {
        _isDarkMode = themeProvider.isDarkTheme;
      });
      _fetchPlans();
    });
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uri =
          Uri.parse('${ApiConfig.baseUrl}/api/admin/driverplan/driver-plans');
      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        throw Exception('Failed to fetch plans (${resp.statusCode})');
      }
      final body = json.decode(resp.body) as Map<String, dynamic>;
      final List<dynamic> data = body['data'] ?? [];
      final mapped = data
          .map<Map<String, dynamic>>((p) => {
                'id': p['id'],
                'name': p['name'] ?? 'Plan',
                'price': p['price']?.toString() ?? '0',
                'durationDays': p['durationDays'] ?? 0,
                'billingCycle': p['billingCycle'] ?? '',
                'features': List<String>.from(p['benefits'] ?? []),
                'color': const Color(0xFF4CAF50),
                'isPopular': true,
              })
          .toList();
      setState(() {
        _plans = mapped;
        _selectedPlanIndex = _plans.isNotEmpty ? 0 : 0;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _selectPlan(int index) {
    setState(() {
      _selectedPlanIndex = index;
    });
  }

  Future<void> _purchasePlan() async {
    if (_plans.isEmpty) return;
    final selectedPlan = _plans[_selectedPlanIndex];
    final double amount =
        double.tryParse(selectedPlan['price']?.toString() ?? '0') ?? 0;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Confirm Purchase',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'You are about to purchase ${selectedPlan['name']} plan for ₹${amount.toStringAsFixed(2)}\n\nProceed with payment?',
          style: TextStyle(
            color: _isDarkMode ? Colors.white.withOpacity(0.8) : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedPlan['color'],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Purchase'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    try {
      setState(() {
        _isLoading = true;
      });
      final uri =
          Uri.parse('${ApiConfig.baseUrl}/api/driver/payment/payu/create');
      final driverId =
          UserSessionService.instance.currentUser?['id']?.toString() ?? '';
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'amount': amount,
            'planId': selectedPlan['id'],
            'receipt': 'OKDriver Driver Plan',
            'callbackBaseUrl': ApiConfig.baseUrl,
            'driverId': driverId
          }));
      if (resp.statusCode != 200) {
        throw Exception('Payment init failed (${resp.statusCode})');
      }
      final body = json.decode(resp.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Payment init failed');
      }
      final String action = body['action'];
      final Map<String, dynamic> params =
          Map<String, dynamic>.from(body['params'] as Map);

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PayuCheckoutWebView(actionUrl: action, params: params),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Payment error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to theme changes
    final themeProvider = Provider.of<ThemeProvider>(context);
    _isDarkMode = themeProvider.isDarkTheme;
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: _isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Choose Your Plan',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _isDarkMode ? Colors.white : Colors.black54,
            ),
            onPressed: () {
              final themeProvider =
                  Provider.of<ThemeProvider>(context, listen: false);
              themeProvider.toggleTheme();
              setState(() {
                _isDarkMode = themeProvider.isDarkTheme;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.diamond_outlined,
                  size: 48,
                  color: _isDarkMode ? Colors.white : const Color(0xFF4CAF50),
                ),
                const SizedBox(height: 12),
                Text(
                  'Unlock Premium Features',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the plan that best fits your driving needs',
                  style: TextStyle(
                    color: _isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black54,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          if (_isLoading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: TextStyle(
                    color: _isDarkMode ? Colors.red[200] : Colors.red[700]),
              ),
            ),

          // Plans List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _plans.length,
              itemBuilder: (context, index) {
                final plan = _plans[index];
                final isSelected = index == _selectedPlanIndex;

                return GestureDetector(
                  onTap: () => _selectPlan(index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (plan['color'] as Color).withOpacity(0.1)
                          : (_isDarkMode
                              ? const Color(0xFF1E1E1E)
                              : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: plan['color'], width: 2)
                          : Border.all(
                              color: _isDarkMode
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.2),
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: _isDarkMode
                              ? Colors.black.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Plan Header
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      plan['name'],
                                      style: TextStyle(
                                        color: isSelected
                                            ? plan['color']
                                            : (_isDarkMode
                                                ? Colors.white
                                                : Colors.black87),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (plan['isPopular']) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CAF50),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'POPULAR',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '₹' +
                                            (double.tryParse(
                                                        (plan['price'] ?? '0')
                                                            .toString()) ??
                                                    0)
                                                .toStringAsFixed(2),
                                        style: TextStyle(
                                          color: isSelected
                                              ? plan['color']
                                              : (_isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87),
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '/${plan['durationDays']} days',
                                        style: TextStyle(
                                          color: _isDarkMode
                                              ? Colors.white.withOpacity(0.6)
                                              : Colors.black54,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? plan['color']
                                      : (_isDarkMode
                                          ? Colors.white.withOpacity(0.4)
                                          : Colors.grey),
                                  width: 2,
                                ),
                                color: isSelected
                                    ? plan['color']
                                    : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Features List
                        ...((plan['features'] as List<String>).map(
                          (feature) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: isSelected
                                      ? plan['color']
                                      : const Color(0xFF4CAF50),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    feature,
                                    style: TextStyle(
                                      color: _isDarkMode
                                          ? Colors.white.withOpacity(0.8)
                                          : Colors.black54,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )).toList(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Purchase Button
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _plans.isEmpty ? null : _purchasePlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _plans.isEmpty
                      ? (_isDarkMode ? Colors.grey[800] : Colors.grey[300])
                      : _plans[_selectedPlanIndex]['color'],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  _plans.isEmpty
                      ? 'No plans available'
                      : 'Purchase ${_plans[_selectedPlanIndex]['name']} Plan',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
