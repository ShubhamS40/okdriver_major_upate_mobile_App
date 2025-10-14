import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:okdriver/language/app_localizations.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  late bool _isDarkMode;
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _priority = 'medium';

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          AppLocalizations.of(context).translate('help_support'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).translate('help_support_blurb'),
              style: TextStyle(
                color: _isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),

            // Subject
            _buildInputCard(
              child: TextField(
                controller: _subjectController,
                style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)
                      .translate('subject_placeholder'),
                  labelText: AppLocalizations.of(context).translate('subject'),
                  hintStyle: TextStyle(
                      color: _isDarkMode ? Colors.white54 : Colors.black45),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Priority
            _buildInputCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('priority'),
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white70 : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _priority,
                    items: [
                      DropdownMenuItem(
                        value: 'low',
                        child: Text(AppLocalizations.of(context)
                            .translate('priority_low')),
                      ),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Text(AppLocalizations.of(context)
                            .translate('priority_medium')),
                      ),
                      DropdownMenuItem(
                        value: 'high',
                        child: Text(AppLocalizations.of(context)
                            .translate('priority_high')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _priority = value);
                    },
                    dropdownColor:
                        _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Description
            _buildInputCard(
              child: TextField(
                controller: _descriptionController,
                maxLines: 6,
                style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)
                      .translate('description_placeholder'),
                  labelText:
                      AppLocalizations.of(context).translate('description'),
                  hintStyle: TextStyle(
                      color: _isDarkMode ? Colors.white54 : Colors.black45),
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)
                          .translate('ticket_created')),
                    ),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context).translate('create_ticket'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 8),
            Text(
              'Our team will respond via email within 24 hours.',
              style: TextStyle(
                color: _isDarkMode ? Colors.white54 : Colors.black45,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: child,
    );
  }
}
