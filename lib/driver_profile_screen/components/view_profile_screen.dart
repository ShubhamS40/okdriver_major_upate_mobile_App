import 'package:flutter/material.dart';
import 'package:okdriver/service/usersession_service.dart';

class ViewProfileScreen extends StatelessWidget {
  const ViewProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = UserSessionService.instance;
    final user = session.currentUser ?? {};
    final sub = user['activeSubscription'];
    final plan = sub != null ? sub['plan'] : null;

    String formatDate(String? iso) {
      if (iso == null) return '';
      try {
        return DateTime.parse(iso).toLocal().toString().split(' ').first;
      } catch (_) {
        return iso;
      }
    }

    int daysLeft() {
      try {
        final end = DateTime.parse(sub['endAt']);
        return end.difference(DateTime.now()).inDays.clamp(0, 100000);
      } catch (_) {
        return 0;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile('Name',
              '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()),
          _tile('Email', user['email']?.toString() ?? ''),
          _tile('Phone', user['phone']?.toString() ?? ''),
          const Divider(height: 32),
          Text('Subscription', style: Theme.of(context).textTheme.titleMedium),
          if (sub == null) const Text('No active subscription'),
          if (sub != null) ...[
            _tile('Plan', plan?['name']?.toString() ?? ''),
            _tile('Description', plan?['description']?.toString() ?? ''),
            _tile('Price', plan?['price']?.toString() ?? ''),
            _tile('Duration',
                '${plan?['durationDays'] ?? ''} days (${plan?['billingCycle'] ?? ''})'),
            _tile('Purchased on', formatDate(sub['startAt']?.toString())),
            _tile('Expires on', formatDate(sub['endAt']?.toString())),
            _tile('Days left', daysLeft().toString()),
            const SizedBox(height: 8),
            if (plan?['benefits'] != null) ...[
              const Text('Benefits:'),
              const SizedBox(height: 6),
              ...List<String>.from(plan!['benefits']).map((b) => Row(
                    children: [
                      const Icon(Icons.check,
                          size: 14, color: Color(0xFF4CAF50)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(b)),
                    ],
                  )),
            ],
          ],
        ],
      ),
    );
  }

  Widget _tile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 130,
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}
