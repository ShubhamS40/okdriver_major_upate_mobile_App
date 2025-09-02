import 'package:flutter/material.dart';

class ClientLoginHeader extends StatelessWidget {
  final bool otpSent;

  const ClientLoginHeader({Key? key, required this.otpSent}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          otpSent ? 'Verify OTP' : 'Client Login',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 16),

        // Subtitle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            otpSent ? 'Email Verification' : 'Fleet Manager Access',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 20),

        // Description
        Text(
          otpSent
              ? 'Enter the OTP sent to your email to verify your account.'
              : 'Enter your email address to receive an OTP for secure login.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            height: 1.6,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
