// Buy Plan Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:okdriver/theme/theme_provider.dart';

class BuyPlanScreen extends StatefulWidget {
  const BuyPlanScreen({super.key});

  @override
  State<BuyPlanScreen> createState() => _BuyPlanScreenState();
}

class _BuyPlanScreenState extends State<BuyPlanScreen> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    // Initialize _isDarkMode from ThemeProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      setState(() {
        _isDarkMode = themeProvider.isDarkTheme;
      });
    });
  }

  int _selectedPlanIndex = 1; // Default to Premium plan

  final List<Map<String, dynamic>> _plans = [
    {
      'name': 'Basic',
      'price': '₹99',
      'duration': '/month',
      'features': [
        'Basic DashCam Recording',
        'Emergency SOS',
        'Email Support',
        '720p Video Quality',
        '30-day Trip History',
      ],
      'color': const Color(0xFF2196F3),
      'isPopular': false,
    },
    {
      'name': 'Premium',
      'price': '₹199',
      'duration': '/month',
      'features': [
        'HD DashCam Recording',
        'Emergency SOS with GPS',
        'Drowsiness Detection',
        'AI Voice Assistant',
        'Priority Support',
        '1080p Video Quality',
        'Unlimited Trip History',
        'Cloud Storage (5GB)',
      ],
      'color': const Color(0xFF4CAF50),
      'isPopular': true,
    },
    {
      'name': 'Pro',
      'price': '₹299',
      'duration': '/month',
      'features': [
        'All Premium Features',
        '4K Video Recording',
        'Advanced AI Analytics',
        'Real-time Fleet Monitoring',
        '24/7 Phone Support',
        'Unlimited Cloud Storage',
        'Multi-vehicle Support',
        'Custom Reports',
        'API Access',
      ],
      'color': const Color(0xFFFFD700),
      'isPopular': false,
    },
  ];

  void _selectPlan(int index) {
    setState(() {
      _selectedPlanIndex = index;
    });
  }

  void _purchasePlan() {
    final selectedPlan = _plans[_selectedPlanIndex];

    showDialog(
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
          'You are about to purchase ${selectedPlan['name']} plan for ${selectedPlan['price']}${selectedPlan['duration']}.\n\nProceed with payment?',
          style: TextStyle(
            color: _isDarkMode ? Colors.white.withOpacity(0.8) : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement payment logic here
              _showPaymentSuccess();
            },
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
  }

  void _showPaymentSuccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF4CAF50),
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              'Success!',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Your plan has been activated successfully. Enjoy premium features!',
          style: TextStyle(
            color: _isDarkMode ? Colors.white.withOpacity(0.8) : Colors.black54,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
                                        text: plan['price'],
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
                                        text: plan['duration'],
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
                onPressed: _purchasePlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _plans[_selectedPlanIndex]['color'],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'Purchase ${_plans[_selectedPlanIndex]['name']} Plan',
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
