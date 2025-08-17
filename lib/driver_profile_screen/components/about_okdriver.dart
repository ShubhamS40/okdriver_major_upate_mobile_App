// About OkDriver Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:okdriver/theme/theme_provider.dart';

class AboutOkDriverScreen extends StatefulWidget {
  const AboutOkDriverScreen({super.key});

  @override
  State<AboutOkDriverScreen> createState() => _AboutOkDriverScreenState();
}

class _AboutOkDriverScreenState extends State<AboutOkDriverScreen> {
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
          'About OkDriver',
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
              setState(() {
                _isDarkMode = !_isDarkMode;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Logo and Version
            _buildAppHeader(),

            const SizedBox(height: 30),

            // App Description
            _buildSection(
              title: 'About Our App',
              content:
                  'OkDriver is a comprehensive driver safety application designed to enhance road safety through advanced AI technology and real-time monitoring. Our mission is to reduce accidents and save lives by providing intelligent driving assistance.',
            ),

            const SizedBox(height: 20),

            // Features Section
            _buildFeaturesSection(),

            const SizedBox(height: 20),

            // Company Info
            _buildSection(
              title: 'Company Information',
              content:
                  'Developed by SafeDrive Technologies Pvt. Ltd.\nFounded in 2023 with a vision to make roads safer for everyone through innovative technology solutions.',
            ),

            const SizedBox(height: 20),

            // Version Info
            _buildVersionInfo(),

            const SizedBox(height: 20),

            // Contact Info
            _buildContactInfo(),

            const SizedBox(height: 30),

            // Legal Links
            _buildLegalLinks(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'OkDriver',
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Version 1.0.0',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              color:
                  _isDarkMode ? Colors.white.withOpacity(0.8) : Colors.black54,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    final features = [
      {
        'icon': Icons.videocam_rounded,
        'title': 'DashCam Recording',
        'desc': 'Record your journeys for safety'
      },
      {
        'icon': Icons.sos_rounded,
        'title': 'Emergency SOS',
        'desc': 'Quick help in critical situations'
      },
      {
        'icon': Icons.visibility_rounded,
        'title': 'Drowsiness Detection',
        'desc': 'AI-powered alertness monitoring'
      },
      {
        'icon': Icons.smart_toy_rounded,
        'title': 'AI Assistant',
        'desc': 'Voice-enabled driving companion'
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Features',
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...features
              .map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            feature['icon'] as IconData,
                            color: const Color(0xFF4CAF50),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feature['title'] as String,
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                feature['desc'] as String,
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white.withOpacity(0.6)
                                      : Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Version Information',
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('App Version:', '1.0.0'),
          _buildInfoRow('Build Number:', '100'),
          _buildInfoRow('Release Date:', 'July 2025'),
          _buildInfoRow('Platform:', 'Flutter'),
        ],
      ),
    );
  }

  Widget _buildContactInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Us',
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildContactRow(
              Icons.email_rounded, 'Email:', 'support@okdriver.com'),
          _buildContactRow(Icons.phone_rounded, 'Phone:', '+91 9876543210'),
          _buildContactRow(Icons.web_rounded, 'Website:', 'www.okdriver.com'),
          _buildContactRow(Icons.location_on_rounded, 'Address:',
              'Mumbai, Maharashtra, India'),
        ],
      ),
    );
  }

  Widget _buildLegalLinks() {
    return Column(
      children: [
        _buildLegalLinkCard('Privacy Policy', Icons.privacy_tip_outlined),
        const SizedBox(height: 12),
        _buildLegalLinkCard('Terms of Service', Icons.description_outlined),
        const SizedBox(height: 12),
        _buildLegalLinkCard('Licenses', Icons.article_outlined),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color:
                  _isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF4CAF50),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color:
                  _isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalLinkCard(String title, IconData icon) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Navigate to legal document
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: _isDarkMode
                    ? Colors.white.withOpacity(0.8)
                    : const Color(0xFF2196F3),
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: _isDarkMode
                    ? Colors.white.withOpacity(0.4)
                    : Colors.black26,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
