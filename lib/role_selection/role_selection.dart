import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int? _selectedRole;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectRole(int roleIndex) {
    setState(() {
      _selectedRole = roleIndex;
    });

    // Add haptic feedback
    // HapticFeedback.selectionClick();

    // Navigate after animation
    Future.delayed(const Duration(milliseconds: 300), () {
      String roleName = '';
      switch (roleIndex) {
        case 0:
          roleName = 'Individual Driver';
          break;
        case 1:
          roleName = 'Fleet User';
          break;
        case 2:
          roleName = 'Fleet Driver';
          break;
      }

      // Navigate to next screen (replace with your navigation)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected: $roleName'),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  const SizedBox(height: 40),

                  // Logo and Title
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_car,
                            size: 40,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'OKDriver',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI-Powered Road Safety',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Title Section
                  const Text(
                    'Select Your Role',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose the option that best describes you',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Role Cards
                  Expanded(
                    child: Column(
                      children: [
                        // Individual Driver Card
                        _buildRoleCard(
                          index: 0,
                          icon: Icons.person_outline,
                          title: 'Individual Driver',
                          subtitle: 'Own Vehicle Owner',
                          description:
                              'Perfect for personal vehicle owners who want to enhance their driving safety with AI-powered dashcam features and drowsiness detection.',
                          features: [
                            'Smart Dashcam Recording',
                            'Drowsiness Detection',
                            'Voice Assistant',
                            'SOS Emergency Alert',
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Fleet User Card
                        _buildRoleCard(
                          index: 1,
                          icon: Icons.business_outlined,
                          title: 'Fleet User',
                          subtitle: 'Fleet Manager/Admin',
                          description:
                              'For fleet operators and managers who need comprehensive vehicle tracking, driver monitoring, and fleet analytics.',
                          features: [
                            'Fleet Dashboard',
                            'Driver Analytics',
                            'Real-time GPS Tracking',
                            'Comprehensive Reports',
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Fleet Driver Card
                        _buildRoleCard(
                          index: 2,
                          icon: Icons.local_shipping_outlined,
                          title: 'Fleet Driver',
                          subtitle: 'Professional Driver',
                          description:
                              'For professional drivers working with fleet operators, providing enhanced safety monitoring and performance tracking.',
                          features: [
                            'Driver Monitoring',
                            'Performance Tracking',
                            'Safety Compliance',
                            'Route Optimization',
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Continue Button
                  if (_selectedRole != null)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => _selectRole(_selectedRole!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 8,
                          shadowColor: Colors.white.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required List<String> features,
  }) {
    final isSelected = _selectedRole == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRole = index;
          });
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.grey.shade900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.grey.shade800,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? Colors.white : Colors.black,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.black.withOpacity(0.7)
                                : Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                description,
                style: TextStyle(
                  color: isSelected
                      ? Colors.black.withOpacity(0.8)
                      : Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: features
                    .map((feature) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.black.withOpacity(0.1)
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            feature,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.black.withOpacity(0.7)
                                  : Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
