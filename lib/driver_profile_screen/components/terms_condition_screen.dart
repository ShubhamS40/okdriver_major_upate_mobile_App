// Terms and Conditions Screen Component
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({Key? key}) : super(key: key);

  @override
  State<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _scrollController.addListener(() {
      if (_scrollController.offset > 300 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 300 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@okdriver.in',
    );
    await launchUrl(emailUri);
  }

  void _launchPhone() async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: '+919319500121',
    );
    await launchUrl(phoneUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: const Text(
            'Terms & Conditions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Stack(
        children: [
          SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(0),
                child: Column(
                  children: [
                    _buildHeaderSection(),
                    _buildContentSection(),
                  ],
                ),
              ),
            ),
          ),
          if (_showScrollToTop)
            Positioned(
              right: 20,
              bottom: 100,
              child: AnimatedOpacity(
                opacity: _showScrollToTop ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: FloatingActionButton(
                  onPressed: _scrollToTop,
                  backgroundColor: Colors.white,
                  child:
                      const Icon(Icons.keyboard_arrow_up, color: Colors.black),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Color(0xFF1A1A1A)],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Terms & Conditions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Please read these terms and conditions carefully before using our services. We\'ve made them clear and straightforward for your understanding.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection() {
    final sections = [
      {
        'title': 'Legal Framework',
        'subtitle':
            'Understanding your rights and responsibilities when using OKDriver services',
        'content':
            'Welcome to OKDriver ("we," "our," or "us"). These Terms and Conditions govern your use of our website, mobile application, and related services.'
      },
      {
        'title': 'Subscription Plans',
        'subtitle': 'Flexible plans designed for your needs',
        'content':
            'OKDriver offers various subscription plans for our Services. The features and pricing of each plan are described on our website and mobile application.'
      },
      {
        'title': 'No Refund Policy',
        'subtitle': 'Clear policy on payments and refunds',
        'content':
            'OKDriver operates under a strict no refund policy. All payments made for our services, including subscription fees, premium features, and other charges are non-refundable.'
      },
      {
        'title': 'Cancellation Policy',
        'subtitle': 'How to manage your subscription',
        'content':
            'You may cancel your subscription at any time through your account settings or by contacting our support team. Cancellation will take effect at the end of your current billing cycle.'
      },
      {
        'title': 'User Accounts',
        'subtitle': 'Your responsibility for account security',
        'content':
            'To use certain features of our Services, you may need to create an account. You are responsible for maintaining the confidentiality of your account credentials.'
      },
      {
        'title': 'Intellectual Property',
        'subtitle': 'Protection of our content and features',
        'content':
            'All content, features, and functionality of our Services, including but not limited to text, graphics, logos, icons, images, and software, are the exclusive property of OKDriver.'
      },
      {
        'title': 'Limitation of Liability',
        'subtitle': 'Understanding service limitations',
        'content':
            'In no event shall OKDriver, its affiliates, or their respective officers, directors, employees, or agents be liable for any indirect, incidental, special, consequential, or punitive damages.'
      },
      {
        'title': 'Changes to Terms',
        'subtitle': 'How we handle updates to these terms',
        'content':
            'We reserve the right to modify these Terms and Conditions at any time. Material changes will be communicated to users through appropriate channels.'
      },
      {
        'title': 'Governing Law',
        'subtitle': 'Legal jurisdiction and compliance',
        'content':
            'These Terms and Conditions shall be governed by and construed in accordance with the laws of the jurisdiction in which OKDriver operates.'
      },
    ];

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: const Text(
              'Terms Overview',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...sections.map((section) => _buildSection(
                section['title']!,
                section['subtitle']!,
                section['content']!,
              )),
          const SizedBox(height: 40), // Added spacing at bottom
        ],
      ),
    );
  }

  Widget _buildSection(String title, String subtitle, String content) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        leading: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            height: 1.3,
          ),
        ),
        children: [
          Text(
            content,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
