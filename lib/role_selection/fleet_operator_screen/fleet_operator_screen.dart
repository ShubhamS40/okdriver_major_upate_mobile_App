import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:okdriver/role_selection/fleet_operator_screen/components/fleet_operator_header.dart';
import 'package:okdriver/role_selection/driver_login_screen/driver_login_screen.dart';
import 'package:okdriver/role_selection/client_login_screen/client_login_screen.dart';

class FleetOperatorScreen extends StatefulWidget {
  const FleetOperatorScreen({Key? key}) : super(key: key);

  @override
  State<FleetOperatorScreen> createState() => _FleetOperatorScreenState();
}

class _FleetOperatorScreenState extends State<FleetOperatorScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutQuart,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _navigateToDriverLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DriverLoginScreen()),
    );
  }

  void _navigateToClientLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ClientLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0A0A0A),
                  Colors.black,
                  const Color(0xFF1A1A1A).withOpacity(0.3),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),

                    const SizedBox(height: 20),

                    // Header
                    const FleetOperatorHeader(),

                    const SizedBox(height: 40),

                    // Login options
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Driver Login Button
                          _buildLoginOptionCard(
                            title: 'Driver Login',
                            subtitle: 'For fleet drivers',
                            icon: Icons.drive_eta_rounded,
                            color: const Color(0xFF4CAF50),
                            onTap: _navigateToDriverLogin,
                          ),

                          const SizedBox(height: 20),

                          // Client Login Button
                          _buildLoginOptionCard(
                            title: 'Client Login',
                            subtitle: 'For fleet managers',
                            icon: Icons.business_center_rounded,
                            color: const Color(0xFF2196F3),
                            onTap: _navigateToClientLogin,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onTap();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: color,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
