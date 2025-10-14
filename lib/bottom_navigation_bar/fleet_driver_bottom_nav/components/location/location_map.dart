import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationMap extends StatefulWidget {
  final LatLng initialPosition;
  final String driverName;
  final String vehicleNumber;
  final bool isTracking;

  const LocationMap({
    Key? key,
    required this.initialPosition,
    required this.driverName,
    required this.vehicleNumber,
    required this.isTracking,
  }) : super(key: key);

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
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
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Map
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initialPosition,
                initialZoom: 15.0,
                minZoom: 5.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.okdriver.app',
                  maxZoom: 18,
                  errorTileCallback: (tile, error, stackTrace) {
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

            // Zoom Controls
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                children: [
                  _buildMapControl(
                    icon: Icons.add,
                    onTap: _zoomIn,
                  ),
                  const SizedBox(height: 8),
                  _buildMapControl(
                    icon: Icons.remove,
                    onTap: _zoomOut,
                  ),
                  const SizedBox(height: 8),
                  _buildMapControl(
                    icon: Icons.my_location,
                    onTap: _centerToCurrentLocation,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.isTracking
                ? Colors.green.shade700
                : Colors.grey.shade600,
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
              Icons.directions_car,
              color: widget.isTracking
                  ? Colors.green.shade700
                  : Colors.grey.shade600,
              size: 40,
            ),
            if (widget.isTracking)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 24,
            color: Colors.black87,
          ),
        ),
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

  void _centerToCurrentLocation() {
    try {
      _mapController.move(
        widget.initialPosition,
        _mapController.camera.zoom,
      );
    } catch (e) {
      debugPrint('Error centering to location: $e');
    }
  }
}
