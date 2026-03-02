import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _entryController;
  late AnimationController _fabController;
  late Animation<double> _entryAnimation;
  late Animation<double> _fabAnimation;

  bool _showBackToTop = false;
  final Set<int> _expandedSections = {};

  // OKDriver Brand Colors (from website)
  static const Color _bgPrimary = Color(0xFF0A0A0A); // near-black
  static const Color _bgCard = Color(0xFF141414);
  static const Color _bgCardHover = Color(0xFF1C1C1C);
  static const Color _borderDim = Color(0xFF2A2A2A);
  static const Color _borderActive = Color(0xFF444444);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFF999999);
  static const Color _textMuted = Color(0xFF555555);
  static const Color _accentWhite = Color(0xFFFFFFFF);
  static const Color _accentGray = Color(0xFFCCCCCC);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOutBack,
    );

    Future.delayed(const Duration(milliseconds: 80), _entryController.forward);
  }

  void _onScroll() {
    final show = _scrollController.offset > 250;
    if (show != _showBackToTop) {
      setState(() => _showBackToTop = show);
      show ? _fabController.forward() : _fabController.reverse();
    }
  }

  void _scrollToTop() => _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );

  void _toggleSection(int index) {
    HapticFeedback.selectionClick();
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
    _entryController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  // ── DATA ──────────────────────────────────────────────────────────────────

  static const List<Map<String, dynamic>> _sections = [
    {
      'title': 'Information We Collect',
      'subtitle': 'What data we gather from you',
      'icon': Icons.fingerprint,
      'details': [
        'Personal identification — name, email, phone number',
        'Location data for ride and navigation services',
        'Device information and usage patterns',
        'Payment and transaction information',
        'Communication records and in-app feedback',
        'Dashcam footage and driving session data',
      ],
    },
    {
      'title': 'How We Use Your Data',
      'subtitle': 'Purposes behind data processing',
      'icon': Icons.settings_suggest_outlined,
      'details': [
        'Providing, maintaining, and improving our services',
        'Processing transactions and managing payments',
        'Delivering real-time safety alerts and notifications',
        'Training AI models for drowsiness detection',
        'Complying with legal and regulatory requirements',
        'Personalising your in-app experience',
      ],
    },
    {
      'title': 'Data Sharing',
      'subtitle': 'When and with whom we share',
      'icon': Icons.hub_outlined,
      'details': [
        'Service providers and infrastructure partners',
        'Emergency services when SOS is triggered',
        'Fleet operators (for B2B users) per agreement',
        'Regulatory authorities when required by law',
        'Business transfers or corporate restructuring',
        'Third parties only with your explicit consent',
      ],
    },
    {
      'title': 'Security Measures',
      'subtitle': 'How we protect your information',
      'icon': Icons.lock_outline,
      'details': [
        'End-to-end encryption for sensitive transmissions',
        'AES-256 encryption for stored data at rest',
        'Regular independent security audits',
        'Role-based access controls and least privilege',
        'Automated threat monitoring and alerting',
        'Documented incident response procedures',
      ],
    },
    {
      'title': 'Your Privacy Rights',
      'subtitle': 'Control over your personal data',
      'icon': Icons.verified_user_outlined,
      'details': [
        'Right to access a copy of your data',
        'Right to correct inaccurate information',
        'Right to delete your account and data',
        'Right to restrict or object to processing',
        'Right to data portability in machine-readable format',
        'Right to withdraw consent at any time',
      ],
    },
    {
      'title': 'Cookies & Tracking',
      'subtitle': 'Technologies we use to remember you',
      'icon': Icons.cookie_outlined,
      'details': [
        'Essential cookies for app functionality',
        'Analytics to understand usage patterns',
        'Preference cookies to remember your settings',
        'You may opt out of non-essential tracking',
        'Do Not Track signals are respected',
      ],
    },
    {
      'title': 'Data Retention',
      'subtitle': 'How long we keep your information',
      'icon': Icons.history_outlined,
      'details': [
        'Account data retained while your account is active',
        'Dashcam footage auto-deleted after 30 days (free tier)',
        'Premium users may extend storage per their plan',
        'Anonymised analytics may be retained indefinitely',
        'You may request immediate deletion at any time',
      ],
    },
    {
      'title': 'Contact & Grievances',
      'subtitle': 'Reach us with privacy concerns',
      'icon': Icons.mail_outline,
      'details': [
        'Email: hello@okdriver.in',
        'Phone: +91-9319500121',
        'Address: L16-A, Dilshad Garden, New Delhi – 110095',
        'Grievance officer response within 72 hours',
        'Escalation to CERT-In if unresolved in 30 days',
      ],
    },
  ];

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: _bgPrimary,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _entryAnimation,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildIntroCard(),
                    const SizedBox(height: 28),
                    _buildSectionHeader('Policy Details'),
                    const SizedBox(height: 16),
                    ..._sections
                        .asMap()
                        .entries
                        .map((e) => _buildExpandableCard(e.key, e.value)),
                    const SizedBox(height: 28),
                    _buildFooterNote(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: _buildFab(),
      ),
    );
  }

  // ── APP BAR ───────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      elevation: 0,
      backgroundColor: _bgPrimary,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _borderDim),
          ),
          child: const Icon(Icons.arrow_back_ios_new,
              color: _textPrimary, size: 16),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _buildHeroHeader(),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _borderDim),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: _bgPrimary,
      ),
      child: Stack(
        children: [
          // Subtle grid texture
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),
          // Glow accent top-right
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: _borderActive),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LEGAL DOCUMENT',
                        style: TextStyle(
                          color: _accentGray,
                          fontSize: 10,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Privacy\nPolicy',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'okdriver.in · Last updated June 2025',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── INTRO CARD ─────────────────────────────────────────────────────────────

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_outlined,
                    color: Colors.black, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Your Privacy Matters',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'At OKDriver, we are committed to safeguarding your personal data. This policy explains in plain language what we collect, why we collect it, and how you can exercise your rights.',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 16),
          // Quick stats row
          Row(
            children: [
              _buildStat('GDPR', 'Compliant'),
              _buildStatDivider(),
              _buildStat('256-bit', 'Encrypted'),
              _buildStatDivider(),
              _buildStat('No Ads', 'Zero Tracking'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildStatDivider() => Container(
        width: 1,
        height: 28,
        color: _borderDim,
      );

  // ── SECTION HEADER ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            )),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── EXPANDABLE CARD ────────────────────────────────────────────────────────

  Widget _buildExpandableCard(int index, Map<String, dynamic> section) {
    final isExpanded = _expandedSections.contains(index);
    final details = section['details'] as List<String>;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _toggleSection(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: isExpanded ? _bgCardHover : _bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isExpanded ? _borderActive : _borderDim,
              width: isExpanded ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Number badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isExpanded ? Colors.white : _borderDim,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isExpanded
                          ? Icon(section['icon'] as IconData,
                              color: Colors.black, size: 16)
                          : Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: _textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section['title'] as String,
                            style: TextStyle(
                              color: isExpanded ? _textPrimary : _accentGray,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            section['subtitle'] as String,
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 280),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: isExpanded ? _textPrimary : _textMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // Expanded details
              AnimatedCrossFade(
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 280),
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      Container(
                          height: 1,
                          color: _borderDim,
                          margin: const EdgeInsets.only(bottom: 14)),
                      ...details.map((d) => _buildDetailRow(d)).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: _textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── FOOTER NOTE ────────────────────────────────────────────────────────────

  Widget _buildFooterNote() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: _borderDim),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.update, color: _textMuted, size: 14),
              SizedBox(width: 6),
              Text(
                'POLICY UPDATES',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 10,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'We may update this policy periodically. Continued use of OKDriver after changes constitutes acceptance. Significant changes will be notified via email or in-app message.',
            style: TextStyle(
              color: _textMuted,
              fontSize: 13,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child:
                    _buildContactChip(Icons.mail_outline, 'hello@okdriver.in'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _buildContactChip(Icons.phone_outlined, '+91-9319500121'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // OKDriver branding strip
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'OKDriver — Drive Safe. Drive Smart.',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderDim),
      ),
      child: Row(
        children: [
          Icon(icon, color: _textMuted, size: 13),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _textSecondary, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFab() {
    return GestureDetector(
      onTap: _scrollToTop,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child:
            const Icon(Icons.keyboard_arrow_up, color: Colors.black, size: 22),
      ),
    );
  }
}

// ── GRID BACKGROUND PAINTER ────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 0.5;

    const spacing = 32.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
