import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:okdriver/service/api_config.dart';
import 'package:okdriver/service/client_session_service.dart';

class VehicleLocationHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const VehicleLocationHistoryScreen({
    Key? key,
    required this.vehicle,
  }) : super(key: key);

  @override
  State<VehicleLocationHistoryScreen> createState() =>
      _VehicleLocationHistoryScreenState();
}

class _VehicleLocationHistoryScreenState
    extends State<VehicleLocationHistoryScreen> {
  final MapController _mapController = MapController();

  List<Map<String, dynamic>> _locationHistory = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filter options
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 1;
  int _totalPages = 1;
  static const int _itemsPerPage = 50;

  // Map state
  LatLng _mapCenter = const LatLng(20.5937, 78.9629);
  double _mapZoom = 10.0;

  // Statistics
  double _averageSpeed = 0.0;
  double _maxSpeed = 0.0;
  double _totalDistance = 0.0;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeHistory();
  }

  Future<void> _initializeHistory() async {
    try {
      // Set default date range (last 7 days)
      final now = DateTime.now();
      _endDate = now;
      _startDate = now.subtract(const Duration(days: 7));

      await _loadLocationHistory();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLocationHistory() async {
    try {
      setState(() => _isLoading = true);

      final token = await _getClientToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final queryParams = {
        'page': _currentPage.toString(),
        'limit': _itemsPerPage.toString(),
        if (_startDate != null) 'startDate': _startDate!.toIso8601String(),
        if (_endDate != null) 'endDate': _endDate!.toIso8601String(),
      };

      final uri = Uri.parse(
              '${ApiConfig.baseUrl}/api/company/clients/assigned-vehicles/${widget.vehicle['vehicleId']}/history')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            _locationHistory =
                List<Map<String, dynamic>>.from(data['data']['locations']);
            _totalPages = data['data']['pagination']['totalPages'];
            _isLoading = false;
          });

          _calculateStatistics();
          _updateMapCenter();
        } else {
          throw Exception(data['message'] ?? 'Failed to load location history');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load location history: $e';
        _isLoading = false;
      });
    }
  }

  Future<String?> _getClientToken() async {
    // Initialize the client session service if not already done
    await ClientSessionService.instance.initialize();
    return ClientSessionService.instance.authToken;
  }

  void _calculateStatistics() {
    if (_locationHistory.isEmpty) return;

    double totalSpeed = 0.0;
    double maxSpeed = 0.0;
    double totalDistance = 0.0;

    for (int i = 0; i < _locationHistory.length - 1; i++) {
      final current = _locationHistory[i];
      final next = _locationHistory[i + 1];

      // Calculate distance between consecutive points
      final distance = _calculateDistance(
          current['lat'], current['lng'], next['lat'], next['lng']);
      totalDistance += distance;

      // Track speed statistics
      if (current['speedKph'] != null) {
        totalSpeed += current['speedKph'];
        if (current['speedKph'] > maxSpeed) {
          maxSpeed = current['speedKph'];
        }
      }
    }

    // Calculate average speed
    final speedCount =
        _locationHistory.where((loc) => loc['speedKph'] != null).length;
    final averageSpeed = speedCount > 0 ? totalSpeed / speedCount : 0.0;

    // Calculate total duration
    final firstLocation = _locationHistory.last;
    final lastLocation = _locationHistory.first;
    final totalDuration = DateTime.parse(lastLocation['recordedAt'])
        .difference(DateTime.parse(firstLocation['recordedAt']));

    setState(() {
      _averageSpeed = averageSpeed;
      _maxSpeed = maxSpeed;
      _totalDistance = totalDistance;
      _totalDuration = totalDuration;
    });
  }

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final dLat = (lat2 - lat1) * (3.14159 / 180);
    final dLng = (lng2 - lng1) * (3.14159 / 180);

    final a = pow(sin(dLat / 2), 2) +
        cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) * pow(sin(dLng / 2), 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  void _updateMapCenter() {
    if (_locationHistory.isEmpty) return;

    double totalLat = 0;
    double totalLng = 0;

    for (final location in _locationHistory) {
      totalLat += location['lat'];
      totalLng += location['lng'];
    }

    final centerLat = totalLat / _locationHistory.length;
    final centerLng = totalLng / _locationHistory.length;

    setState(() {
      _mapCenter = LatLng(centerLat, centerLng);
    });

    // Only move map controller if the map is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(_mapCenter, _mapZoom);
      }
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
        end: _endDate ?? DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _currentPage = 1;
      });

      await _loadLocationHistory();
    }
  }

  void _changePage(int page) {
    if (page >= 1 && page <= _totalPages) {
      setState(() {
        _currentPage = page;
      });
      _loadLocationHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.vehicle['vehicleNumber']} - History'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.red[700]),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLocationHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_locationHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Location History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'No location data found for the selected date range.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Statistics cards
        _buildStatisticsCards(),

        // Map
        Expanded(
          flex: 2,
          child: _buildMap(),
        ),

        // Location list
        Expanded(
          flex: 1,
          child: _buildLocationList(),
        ),

        // Pagination
        _buildPagination(),
      ],
    );
  }

  Widget _buildStatisticsCards() {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
              child: _buildStatCard('Avg Speed',
                  '${_averageSpeed.toStringAsFixed(1)} km/h', Icons.speed)),
          Expanded(
              child: _buildStatCard('Max Speed',
                  '${_maxSpeed.toStringAsFixed(1)} km/h', Icons.trending_up)),
          Expanded(
              child: _buildStatCard('Distance',
                  '${_totalDistance.toStringAsFixed(1)} km', Icons.route)),
          Expanded(
              child: _buildStatCard('Duration', _formatDuration(_totalDuration),
                  Icons.access_time)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.blue[600]),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _mapCenter,
        initialZoom: _mapZoom,
        minZoom: 3.0,
        maxZoom: 18.0,
        onMapReady: () {
          print('🗺️ FlutterMap is ready and rendered');
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.okdriver.app',
          maxZoom: 18,
        ),
        PolylineLayer(
          polylines: _buildRoutePolyline(),
        ),
        MarkerLayer(
          markers: _buildLocationMarkers(),
        ),
      ],
    );
  }

  List<Polyline> _buildRoutePolyline() {
    if (_locationHistory.length < 2) return [];

    final points = _locationHistory.map((location) {
      return LatLng(location['lat'], location['lng']);
    }).toList();

    return [
      Polyline(
        points: points,
        strokeWidth: 3.0,
        color: Colors.blue,
      ),
    ];
  }

  List<Marker> _buildLocationMarkers() {
    final markers = <Marker>[];

    // Add start marker
    if (_locationHistory.isNotEmpty) {
      final startLocation = _locationHistory.last;
      markers.add(
        Marker(
          width: 30.0,
          height: 30.0,
          point: LatLng(startLocation['lat'], startLocation['lng']),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
          ),
        ),
      );
    }

    // Add end marker
    if (_locationHistory.isNotEmpty) {
      final endLocation = _locationHistory.first;
      markers.add(
        Marker(
          width: 30.0,
          height: 30.0,
          point: LatLng(endLocation['lat'], endLocation['lng']),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.stop, color: Colors.white, size: 16),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildLocationList() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[100],
          child: Row(
            children: [
              const Text('Time', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              const Text('Location',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              const Text('Speed',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        // List
        Expanded(
          child: ListView.builder(
            itemCount: _locationHistory.length,
            itemBuilder: (context, index) {
              final location = _locationHistory[index];
              return _buildLocationListItem(location, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocationListItem(Map<String, dynamic> location, int index) {
    final recordedAt = DateTime.parse(location['recordedAt']);
    final speed = location['speedKph'];
    final lat = location['lat'];
    final lng = location['lng'];

    return ListTile(
      dense: true,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(
        _formatTime(recordedAt),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
        style: const TextStyle(fontSize: 10),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: speed != null ? _getSpeedColor(speed) : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          speed != null ? '${speed.toStringAsFixed(1)} km/h' : 'N/A',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: speed != null ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
      onTap: () => _focusOnLocation(lat, lng),
    );
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
          ),
          Text('Page $_currentPage of $_totalPages'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () => _changePage(_currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Color _getSpeedColor(double speed) {
    if (speed < 30) return Colors.green;
    if (speed < 60) return Colors.orange;
    if (speed < 90) return Colors.red;
    return Colors.purple;
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  void _focusOnLocation(double lat, double lng) {
    setState(() {
      _mapCenter = LatLng(lat, lng);
      _mapZoom = 15.0;
    });

    // Only move map controller if the map is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(_mapCenter, _mapZoom);
      }
    });
  }
}
