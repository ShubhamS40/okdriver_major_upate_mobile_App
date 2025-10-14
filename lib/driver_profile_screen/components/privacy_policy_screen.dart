import 'package:flutter/material.dart';
import 'package:okdriver/driver_profile_screen/driver_profile_screen.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _headerAnimationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _headerAnimation;
  late Animation<double> _fabAnimation;

  bool _showBackToTop = false;
  Set<int> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _headerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _headerAnimationController, curve: Curves.easeOut),
    );

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _fabAnimationController, curve: Curves.elasticOut),
    );

    _scrollController.addListener(_scrollListener);

    // Start header animation
    Future.delayed(const Duration(milliseconds: 100), () {
      _headerAnimationController.forward();
    });
  }

  void _scrollListener() {
    if (_scrollController.offset > 200 && !_showBackToTop) {
      setState(() => _showBackToTop = true);
      _fabAnimationController.forward();
    } else if (_scrollController.offset <= 200 && _showBackToTop) {
      setState(() => _showBackToTop = false);
      _fabAnimationController.reverse();
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _toggleSection(int index) {
    setState(() {
      if (_expandedSections.contains(index)) {
        _expandedSections.remove(index);
      } else {
        _expandedSections.add(index);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _headerAnimationController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Animated App Bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.black,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: AnimatedBuilder(
                animation: _headerAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 50 * (1 - _headerAnimation.value)),
                    child: Opacity(
                      opacity: _headerAnimation.value,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1A1A1A),
                              Color(0xFF2D2D2D),
                              Colors.black,
                            ],
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.security,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Privacy Policy',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'OKDriver - Your privacy is our priority',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Introduction Card
                  _buildIntroCard(),
                  const SizedBox(height: 20),

                  // Privacy Sections
                  ..._buildPrivacySections(),

                  const SizedBox(height: 20),

                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabAnimation.value,
            child: FloatingActionButton(
              onPressed: _scrollToTop,
              backgroundColor: Colors.black,
              child: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntroCard() {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A90E2).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Introduction',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'At OKDriver, we respect your privacy and are committed to protecting your personal information. This policy explains how we collect, use, and safeguard your data when you use our services.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildPrivacySections() {
    final sections = [
      {
        'title': 'Information We Collect',
        'icon': Icons.data_usage,
        'color': const Color(0xFF10B981),
        'content':
            'We collect personal identification information, location data, device information, payment details, and communication records to provide you with the best service experience.',
        'details': [
          'Personal identification (name, email, phone)',
          'Location data for ride services',
          'Device information and usage patterns',
          'Payment and transaction information',
          'Communication records and feedback'
        ]
      },
      {
        'title': 'How We Use Your Information',
        'icon': Icons.settings_applications,
        'color': const Color(0xFF8B5CF6),
        'content':
            'Your information helps us provide, maintain, and improve our services while ensuring your safety and security.',
        'details': [
          'Providing and maintaining services',
          'Processing transactions and payments',
          'Improving user experience',
          'Sending notifications and updates',
          'Ensuring safety and security',
          'Complying with legal requirements'
        ]
      },
      {
        'title': 'How We Share Your Information',
        'icon': Icons.share,
        'color': const Color(0xFFEF4444),
        'content':
            'We only share your information in specific circumstances to provide our services or when required by law.',
        'details': [
          'With service providers and partners',
          'When required by law',
          'To protect rights and safety',
          'In business transfers or mergers',
          'With your explicit consent'
        ]
      },
      {
        'title': 'Data Security',
        'icon': Icons.security,
        'color': const Color(0xFF06B6D4),
        'content':
            'We implement industry-standard security measures to protect your personal information, though no system is 100% secure.',
        'details': [
          'Encryption of sensitive data',
          'Secure data transmission protocols',
          'Regular security audits',
          'Access controls and monitoring',
          'Incident response procedures'
        ]
      },
      {
        'title': 'Your Privacy Rights',
        'icon': Icons.account_circle,
        'color': const Color(0xFFF59E0B),
        'content':
            'You have various rights regarding your personal information, depending on your location.',
        'details': [
          'Right to access your data',
          'Right to rectify incorrect information',
          'Right to delete your data',
          'Right to restrict processing',
          'Right to data portability',
          'Right to withdraw consent'
        ]
      },
    ];

    return sections.asMap().entries.map((entry) {
      final index = entry.key;
      final section = entry.value;

      return TweenAnimationBuilder(
        duration: Duration(milliseconds: 400 + (index * 100)),
        tween: Tween<double>(begin: 0, end: 1),
        builder: (context, double value, child) {
          return Transform.translate(
            offset: Offset(50 * (1 - value), 0),
            child: Opacity(
              opacity: value,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: _buildExpandableCard(
                  title: section['title'] as String,
                  icon: section['icon'] as IconData,
                  color: section['color'] as Color,
                  content: section['content'] as String,
                  details: section['details'] as List<String>,
                  index: index,
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  Widget _buildExpandableCard({
    required String title,
    required IconData icon,
    required Color color,
    required String content,
    required List<String> details,
    required int index,
  }) {
    final isExpanded = _expandedSections.contains(index);

    return GestureDetector(
      onTap: () => _toggleSection(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded ? color : Colors.grey[200]!,
            width: isExpanded ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isExpanded ? color : Colors.grey).withOpacity(0.1),
              blurRadius: isExpanded ? 15 : 5,
              offset: Offset(0, isExpanded ? 5 : 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isExpanded ? color : Colors.black87,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.expand_more,
                    color: isExpanded ? color : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  ...details
                      .map((detail) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    detail,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ],
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }
}
