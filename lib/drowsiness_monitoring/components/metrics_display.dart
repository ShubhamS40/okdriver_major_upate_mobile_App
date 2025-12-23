import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MetricsDisplay extends StatelessWidget {
  final Map<String, dynamic>? metrics;
  final bool isDarkMode;

  const MetricsDisplay({
    Key? key,
    required this.metrics,
    required this.isDarkMode,
  }) : super(key: key);

  // Changed threshold from 10 to 7 seconds
  static const int THRESHOLD_FRAMES = 7;

  @override
  Widget build(BuildContext context) {
    // Check for drowsiness event completion (when drowsy frames reach 7)
    _checkDrowsinessEvent();

    if (metrics == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Waiting for metrics...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.2)
              : Colors.black.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detection Metrics',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Metrics Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Eye Aspect Ratio',
                  value: metrics!['ear']?.toString() ?? '0.000',
                  unit: '',
                  color: _getEarColor(metrics!['ear'] ?? 0.0),
                  icon: Icons.visibility,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Mouth Aspect Ratio',
                  value: metrics!['mar']?.toString() ?? '0.000',
                  unit: '',
                  color: _getMarColor(metrics!['mar'] ?? 0.0),
                  icon: Icons.face,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'CNN Confidence',
                  value:
                      '${((metrics!['cnn_confidence'] ?? 0.0) * 100).toStringAsFixed(1)}',
                  unit: '%',
                  color: _getConfidenceColor(metrics!['cnn_confidence'] ?? 0.0),
                  icon: Icons.psychology,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Drowsy Frames',
                  value: metrics!['drowsy_frames']?.toString() ?? '0',
                  unit: '',
                  color: _getDrowsyFramesColor(metrics!['drowsy_frames'] ?? 0),
                  icon: Icons.bedtime,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress indicators
          _buildProgressSection(),

          const SizedBox(height: 16),

          // Statistics
          _buildStatisticsSection(),
        ],
      ),
    );
  }

  // Check for drowsiness event completion and print alert
  void _checkDrowsinessEvent() {
    if (metrics != null) {
      final drowsyFrames = metrics!['drowsy_frames'] ?? 0;
      // When drowsy frames reach 7, trigger alert
      if (drowsyFrames >= THRESHOLD_FRAMES) {
        print("Bipp Bipp - Drowsiness Alert! (${drowsyFrames}s)");
        // Optional: Add haptic feedback
        HapticFeedback.vibrate();
      }
    }
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    final drowsyFrames = metrics!['drowsy_frames'] ?? 0;
    final yawningFrames = metrics!['yawning_frames'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detection Progress (7 seconds threshold)',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // Drowsiness Progress
        Row(
          children: [
            Icon(
              Icons.bedtime,
              color: Colors.orange,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Drowsiness',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '$drowsyFrames/${THRESHOLD_FRAMES}s',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: drowsyFrames / THRESHOLD_FRAMES.toDouble(),
                    backgroundColor: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      drowsyFrames >= THRESHOLD_FRAMES
                          ? Colors.red
                          : (drowsyFrames >= 4 ? Colors.orange : Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Yawning Progress
        Row(
          children: [
            Icon(
              Icons.face,
              color: Colors.yellow.shade700,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Yawning',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '$yawningFrames/${THRESHOLD_FRAMES}s',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: yawningFrames / THRESHOLD_FRAMES.toDouble(),
                    backgroundColor: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      yawningFrames >= THRESHOLD_FRAMES
                          ? Colors.red
                          : Colors.yellow.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatisticsSection() {
    final drowsyEvents = metrics!['drowsy_events'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.analytics,
            color: isDarkMode ? Colors.white70 : Colors.black54,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Drowsiness Events',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  drowsyEvents.toString(),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getDrowsyEventsColor(drowsyEvents),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getDrowsyEventsText(drowsyEvents),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getEarColor(double ear) {
    if (ear < 0.25) return Colors.red;
    if (ear < 0.3) return Colors.orange;
    return Colors.green;
  }

  Color _getMarColor(double mar) {
    if (mar > 0.5) return Colors.yellow.shade700;
    return Colors.green;
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) return Colors.green;
    if (confidence > 0.6) return Colors.orange;
    return Colors.red;
  }

  Color _getDrowsyFramesColor(int frames) {
    if (frames >= 5) return Colors.red; // Critical at 5 seconds
    if (frames >= 3) return Colors.orange; // Warning at 3 seconds
    return Colors.green;
  }

  Color _getDrowsyEventsColor(int events) {
    if (events >= 3) return Colors.red;
    if (events >= 1) return Colors.orange;
    return Colors.green;
  }

  String _getDrowsyEventsText(int events) {
    if (events >= 3) return 'CRITICAL';
    if (events >= 1) return 'WARNING';
    return 'SAFE';
  }
}
