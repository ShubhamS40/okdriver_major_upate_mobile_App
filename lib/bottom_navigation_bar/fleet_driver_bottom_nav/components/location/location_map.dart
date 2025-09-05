import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationMap extends StatefulWidget {
  final LatLng initialPosition;
  final String driverName;
  final String vehicleNumber;

  const LocationMap({
    Key? key,
    required this.initialPosition,
    required this.driverName,
    required this.vehicleNumber,
  }) : super(key: key);

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  bool _isLiveLocationEnabled = true;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialPosition,
              initialZoom: 15.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              onTap: (tapPosition, point) {
                // Handle map tap if needed
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.okdriver.app',
                maxZoom: 18,
                errorTileCallback: (tile, error, stackTrace) {
                  // Handle tile loading errors
                  debugPrint('Tile loading error: $error');
                },
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 80.0,
                    height: 80.0,
                    point: widget.initialPosition,
                    child: _buildVehicleMarker(),
                  ),
                ],
              ),
            ],
          ),

          // Controls overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Column(
              children: [
                // Zoom controls
                _buildMapControl(
                  icon: Icons.add,
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 8),
                _buildMapControl(
                  icon: Icons.remove,
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 16),
                // Live location toggle
                _buildLiveLocationToggle(),
              ],
            ),
          ),

          // Driver info card
        ],
      ),
    );
  }

  void _zoomIn() {
    try {
      final currentZoom = _mapController.camera.zoom;
      if (currentZoom < 18.0) {
        _mapController.move(
          _mapController.camera.center,
          (currentZoom + 1).clamp(5.0, 18.0),
        );
      }
    } catch (e) {
      debugPrint('Error zooming in: $e');
    }
  }

  void _zoomOut() {
    try {
      final currentZoom = _mapController.camera.zoom;
      if (currentZoom > 5.0) {
        _mapController.move(
          _mapController.camera.center,
          (currentZoom - 1).clamp(5.0, 18.0),
        );
      }
    } catch (e) {
      debugPrint('Error zooming out: $e');
    }
  }

  Widget _buildVehicleMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            widget.vehicleNumber.isNotEmpty ? widget.vehicleNumber : 'N/A',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.location_on,
              color: Colors.red.shade700,
              size: 40,
            ),
            if (_isLiveLocationEnabled)
              Positioned(
                bottom: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMapControl({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveLocationToggle() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Live',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Switch(
              value: _isLiveLocationEnabled,
              onChanged: _toggleLiveLocation,
              activeColor: Colors.green,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  void _toggleLiveLocation(bool value) {
    if (mounted) {
      setState(() {
        _isLiveLocationEnabled = value;
      });

      // Show feedback to user
      final message = _isLiveLocationEnabled
          ? 'Live location sharing enabled'
          : 'Live location sharing disabled';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildDriverInfoCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(
                    Icons.person,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.driverName.isNotEmpty
                            ? widget.driverName
                            : 'Unknown Driver',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vehicle: ${widget.vehicleNumber.isNotEmpty ? widget.vehicleNumber : 'N/A'}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isLiveLocationEnabled ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isLiveLocationEnabled ? 'Online' : 'Offline',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  icon: Icons.call,
                  label: 'Call',
                  color: Colors.green,
                  onTap: _handleCall,
                ),
                _buildActionButton(
                  icon: Icons.message,
                  label: 'Message',
                  color: Colors.blue,
                  onTap: _handleMessage,
                ),
                _buildActionButton(
                  icon: Icons.directions,
                  label: 'Directions',
                  color: Colors.orange,
                  onTap: _handleDirections,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCall() {
    try {
      // TODO: Implement actual calling functionality
      // Example: launch('tel:$phoneNumber');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calling driver...'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error handling call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to make call'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleMessage() {
    try {
      // TODO: Implement actual messaging functionality
      // Example: launch('sms:$phoneNumber');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening messages...'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error handling message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open messages'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleDirections() {
    try {
      // TODO: Implement actual directions functionality
      // Example: launch('https://maps.google.com/?daddr=${widget.initialPosition.latitude},${widget.initialPosition.longitude}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening directions...'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error handling directions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open directions'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
