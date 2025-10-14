// Main Profile Screen
import 'package:flutter/material.dart';
import 'package:okdriver/driver_profile_screen/components/privacy_policy_screen.dart';
import 'package:okdriver/driver_profile_screen/components/terms_condition_screen.dart';
import 'package:okdriver/service/usersession_service.dart';
import 'package:okdriver/driver_profile_screen/components/about_okdriver.dart';
import 'package:okdriver/driver_profile_screen/components/language_switch.dart';
import 'package:okdriver/driver_profile_screen/components/subscription_plan.dart';
import 'package:okdriver/role_selection/role_selection.dart';
import 'package:provider/provider.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:okdriver/driver_profile_screen/components/help_support_screen.dart';
import 'package:okdriver/language/language_provider.dart';
import 'package:okdriver/language/app_localizations.dart';
import 'package:okdriver/driver_profile_screen/components/view_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ProfileMode { vehicleOwner, fleetDriver, fleetClient }

class ProfileScreen extends StatefulWidget {
  final ProfileMode mode;

  const ProfileScreen({super.key, this.mode = ProfileMode.vehicleOwner});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late bool _isDarkMode;
  String _userName = "John Driver";
  String _userEmail = "john.driver@email.com";
  String _userPlan = "Free Plan";
  String? _vehicleNumber;
  bool _notificationsEnabled = true;

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context).translate('notifications'),
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _notificationsEnabled
                        ? AppLocalizations.of(context).translate('enabled')
                        : AppLocalizations.of(context).translate('disabled'),
                    style: TextStyle(
                      color: _isDarkMode
                          ? Colors.white.withOpacity(0.8)
                          : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  Switch(
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                      Navigator.pop(context);
                    },
                    activeColor: const Color(0xFF4CAF50),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize _isDarkMode from ThemeProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      setState(() {
        _isDarkMode = themeProvider.isDarkTheme;
      });

      // Load user data from session
      _loadUserData();
    });
  }

  // Load user data from session service
  void _loadUserData() {
    final sessionService = UserSessionService.instance;
    if (widget.mode == ProfileMode.vehicleOwner) {
      setState(() {
        _userName = sessionService.getUserDisplayName();
        _userEmail = sessionService.getUserEmail();
        _userPlan =
            sessionService.hasPremiumPlan() ? "Premium Plan" : "Free Plan";
      });
      sessionService.fetchActiveSubscription().then((sub) {
        if (!mounted) return;
        if (sub != null) {
          setState(() {
            _userPlan =
                "${sub['plan']?['name'] ?? 'Premium'} (till ${DateTime.tryParse(sub['endAt'] ?? '')?.toLocal().toString().split(' ').first ?? ''})";
          });
        }
      });
    } else {
      // Fleet driver/client: simplify fields and, for drivers, load vehicle number
      setState(() {
        _userName = sessionService.getUserDisplayName();
        _userEmail = ""; // hide email on fleet profiles
        _userPlan = ""; // hide plan badge on fleet profiles
      });
      if (widget.mode == ProfileMode.fleetDriver) {
        _loadVehicleNumber();
      }
    }
  }

  Future<void> _loadVehicleNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vn = prefs.getString('current_vehicle_number');
      if (mounted) {
        setState(() {
          _vehicleNumber = vn;
        });
      }
    } catch (_) {}
  }

  void _toggleTheme() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.toggleTheme();
    setState(() {
      _isDarkMode = themeProvider.isDarkTheme;
    });
  }

  void _navigateToScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to theme changes
    final themeProvider = Provider.of<ThemeProvider>(context);
    _isDarkMode = themeProvider.isDarkTheme;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final String currentLanguageName =
        languageProvider.getLanguageName(languageProvider.currentLocale);

    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Profile Header
            _buildProfileHeader(),

            // Profile Options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Account Section (only for vehicle owner)
                    if (widget.mode == ProfileMode.vehicleOwner) ...[
                      _buildSectionTitle(
                          AppLocalizations.of(context).translate('account')),
                      _buildOptionCard(
                        icon: Icons.person_outline_rounded,
                        title: 'View Profile',
                        subtitle: 'See your details and subscription plan',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ViewProfileScreen(),
                            ),
                          );
                        },
                      ),
                      _buildOptionCard(
                        icon: Icons.language_rounded,
                        title:
                            AppLocalizations.of(context).translate('language'),
                        subtitle: currentLanguageName,
                        onTap: () =>
                            _navigateToScreen(const LanguageSwitchScreen()),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // App Settings Section
                    _buildSectionTitle(
                        AppLocalizations.of(context).translate('app_settings')),
                    if (widget.mode != ProfileMode.vehicleOwner)
                      _buildOptionCard(
                        icon: Icons.language_rounded,
                        title:
                            AppLocalizations.of(context).translate('language'),
                        subtitle: currentLanguageName,
                        onTap: () =>
                            _navigateToScreen(const LanguageSwitchScreen()),
                      ),
                    _buildOptionCard(
                      icon: Icons.notifications_none_rounded,
                      title: AppLocalizations.of(context)
                          .translate('notifications'),
                      subtitle: _notificationsEnabled
                          ? AppLocalizations.of(context).translate('enabled')
                          : AppLocalizations.of(context).translate('disabled'),
                      onTap: _showNotificationsSheet,
                    ),
                    _buildThemeToggleCard(),

                    const SizedBox(height: 20),

                    // Premium Section
                    if (widget.mode == ProfileMode.vehicleOwner) ...[
                      _buildSectionTitle(
                          AppLocalizations.of(context).translate('premium')),
                      _buildOptionCard(
                        icon: Icons.diamond_outlined,
                        title: AppLocalizations.of(context)
                            .translate('buy_premium_plan'),
                        subtitle: AppLocalizations.of(context)
                            .translate('unlock_premium_features'),
                        onTap: () => _navigateToScreen(const BuyPlanScreen()),
                        isPremium: true,
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Support Section
                    _buildSectionTitle(
                        AppLocalizations.of(context).translate('support_info')),
                    _buildOptionCard(
                        icon: Icons.info_outline_rounded,
                        title: AppLocalizations.of(context)
                            .translate('about_okdriver'),
                        subtitle: AppLocalizations.of(context)
                            .translate('learn_more_about_app'),
                        onTap: () => _navigateToScreen(
                              AboutOkDriverScreen(
                                showDelete:
                                    widget.mode == ProfileMode.vehicleOwner,
                              ),
                            )),
                    _buildOptionCard(
                      icon: Icons.help_outline_rounded,
                      title: AppLocalizations.of(context)
                          .translate('help_support'),
                      subtitle: AppLocalizations.of(context)
                          .translate('get_help_support'),
                      onTap: () {
                        _navigateToScreen(const HelpSupportScreen());
                      },
                    ),
                    _buildOptionCard(
                      icon: Icons.privacy_tip_outlined,
                      title: AppLocalizations.of(context)
                          .translate('privacy_policy'),
                      subtitle: AppLocalizations.of(context)
                          .translate('read privacy & policy'),
                      onTap: () {
                        // Navigate to privacy policy
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const PrivacyPolicyScreen()));
                      },
                    ),
                    _buildOptionCard(
                      icon: Icons.gavel_outlined,
                      title: AppLocalizations.of(context)
                          .translate('Terms & Conditions'),
                      subtitle: AppLocalizations.of(context)
                          .translate('read terms & conditions'),
                      onTap: () {
                        // Navigate to terms and conditions
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const TermsAndConditionsScreen()));
                      },
                    ),

                    const SizedBox(height: 30),

                    // Logout Button
                    _buildLogoutButton(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
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
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context).translate('profile'),
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
            ],
          ),

          const SizedBox(height: 20),

          // Profile Avatar and Info
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset('assets/only_logo.png', fit: BoxFit.cover),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.mode !=
                        ProfileMode
                            .fleetDriver) // 👈 username केवल तब दिखेगा जब fleetDriver न हो
                      Text(
                        _userName,
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (widget.mode != ProfileMode.fleetDriver)
                      const SizedBox(height: 4),
                    if (widget.mode == ProfileMode.fleetDriver &&
                        (_vehicleNumber?.isNotEmpty ?? false))
                      Text(
                        'Vehicle: ${_vehicleNumber!}',
                        style: TextStyle(
                          color: _isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (widget.mode != ProfileMode.fleetDriver &&
                        _userEmail.isNotEmpty)
                      Text(
                        _userEmail,
                        style: TextStyle(
                          color: _isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 4),
                    if (_userPlan.isNotEmpty &&
                        widget.mode == ProfileMode.vehicleOwner)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _userPlan,
                          style: const TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isPremium = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: isPremium
                  ? Border.all(
                      color: const Color(0xFFFFD700),
                      width: 1,
                    )
                  : null,
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPremium
                        ? const Color(0xFFFFD700).withOpacity(0.1)
                        : (_isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : const Color(0xFF2196F3).withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isPremium
                        ? const Color(0xFFFFD700)
                        : (_isDarkMode
                            ? Colors.white.withOpacity(0.8)
                            : const Color(0xFF2196F3)),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color:
                                  _isDarkMode ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isPremium) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: _isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
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
      ),
    );
  }

  Widget _buildThemeToggleCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : const Color(0xFF2196F3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.8)
                  : const Color(0xFF2196F3),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).translate('dark_mode'),
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isDarkMode
                      ? AppLocalizations.of(context)
                          .translate('dark_theme_enabled')
                      : AppLocalizations.of(context)
                          .translate('light_theme_enabled'),
                  style: TextStyle(
                    color: _isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isDarkMode,
            onChanged: (value) => _toggleTheme(),
            activeColor: const Color(0xFF4CAF50),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Show logout confirmation dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor:
                    _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  AppLocalizations.of(context).translate('logout'),
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Text(
                  AppLocalizations.of(context).translate('are_you_sure_logout'),
                  style: TextStyle(
                    color: _isDarkMode
                        ? Colors.white.withOpacity(0.8)
                        : Colors.black54,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      AppLocalizations.of(context).translate('cancel'),
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      // Use session service to logout
                      try {
                        await UserSessionService.instance.logout();

                        // Navigate to role selection screen (login flow)
                        Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (context) =>
                                    const RoleSelectionScreen()),
                            (route) => false);
                      } catch (e) {
                        // Show error
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Logout error: $e')),
                        );
                      }
                    },
                    child: Text(
                      AppLocalizations.of(context).translate('logout'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
