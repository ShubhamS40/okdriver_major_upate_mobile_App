const { PrismaClient } = require('@prisma/client');
const { sendMessage, TOPICS } = require('../../../config/kafka');
const prisma = new PrismaClient();

/**
 * Update live location for a vehicle
 * Now sends to Kafka for async processing instead of direct database writes
 * Called every 5 seconds from fleet driver app
 */
const updateLiveLocation = async (req, res) => {
  try {
    const { vehicleNumber, latitude, longitude, speedKph, headingDeg } = req.body;
    
    console.log('📍 Live location update received:', {
      vehicleNumber,
      lat: latitude,
      lng: longitude,
      speed: speedKph,
      heading: headingDeg,
      timestamp: new Date().toISOString()
    });

    // Validate required fields
    if (!vehicleNumber || latitude === undefined || longitude === undefined) {
      console.log('❌ Missing required fields:', { vehicleNumber, latitude, longitude });
      return res.status(400).json({ 
        message: "vehicleNumber, latitude, and longitude are required" 
      });
    }

    // Validate coordinate ranges
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      console.log('❌ Invalid coordinates:', { latitude, longitude });
      return res.status(400).json({ 
        message: "Invalid coordinates: lat must be -90 to 90, lng must be -180 to 180" 
      });
    }

    // Find vehicle by vehicleNumber to validate it exists
    const vehicle = await prisma.vehicle.findUnique({
      where: { vehicleNumber }
    });

    if (!vehicle) {
      console.log('❌ Vehicle not found:', vehicleNumber);
      return res.status(404).json({ message: "Vehicle not found" });
    }

    console.log('✅ Vehicle found:', { id: vehicle.id, companyId: vehicle.companyId });

    // Prepare location data for Kafka
    const locationData = {
      vehicleNumber,
      latitude: parseFloat(latitude),
      longitude: parseFloat(longitude),
      speedKph: speedKph ? parseFloat(speedKph) : null,
      headingDeg: headingDeg ? parseInt(headingDeg) : null,
      timestamp: new Date().toISOString(),
      vehicleId: vehicle.id,
      companyId: vehicle.companyId
    };

    // Send to Kafka for async processing
    const kafkaSuccess = await sendMessage(TOPICS.VEHICLE_LOCATION_UPDATE, locationData);
    
    if (kafkaSuccess) {
      console.log('✅ Location update sent to Kafka successfully');
      
      return res.status(200).json({
        message: "Location update queued successfully",
        location: {
          vehicleNumber,
          lat: locationData.latitude,
          lng: locationData.longitude,
          speedKph: locationData.speedKph,
          headingDeg: locationData.headingDeg,
          timestamp: locationData.timestamp
        },
        processing: "Location is being processed asynchronously for real-time updates and database storage"
      });
    } else {
      console.log('❌ Failed to send location update to Kafka');
      return res.status(500).json({ 
        message: "Location update queuing failed, please try again" 
      });
    }

  } catch (error) {
    console.error('❌ Error updating live location:', error);
    return res.status(500).json({ 
      message: "Internal server error",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * Get latest location for a vehicle
 * Now optimized to use the last known location from Vehicle table
 */
const getLatestLocation = async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    
    console.log('🔍 Getting latest location for vehicle:', vehicleNumber);

    const vehicle = await prisma.vehicle.findUnique({
      where: { vehicleNumber },
      select: {
        id: true,
        vehicleNumber: true,
        model: true,
        type: true,
        lastLat: true,
        lastLng: true,
        lastLocationAt: true
      }
    });

    if (!vehicle) {
      return res.status(404).json({ message: "Vehicle not found" });
    }

    // Check if we have last known location
    if (vehicle.lastLat && vehicle.lastLng && vehicle.lastLocationAt) {
      return res.status(200).json({
        vehicle: {
          id: vehicle.id,
          vehicleNumber: vehicle.vehicleNumber,
          model: vehicle.model,
          type: vehicle.type
        },
        location: {
          lat: parseFloat(vehicle.lastLat),
          lng: parseFloat(vehicle.lastLng),
          recordedAt: vehicle.lastLocationAt
        },
        source: "last_known_location"
      });
    }

    // Fallback to VehicleLocation table if no last known location
    const latestLocation = await prisma.vehicleLocation.findFirst({
      where: { vehicleId: vehicle.id },
      orderBy: { recordedAt: 'desc' }
    });

    if (!latestLocation) {
      return res.status(404).json({ message: "No location data found for this vehicle" });
    }

    return res.status(200).json({
      vehicle: {
        id: vehicle.id,
        vehicleNumber: vehicle.vehicleNumber,
        model: vehicle.model,
        type: vehicle.type
      },
      location: {
        lat: parseFloat(latestLocation.lat),
        lng: parseFloat(latestLocation.lng),
        speedKph: latestLocation.speedKph ? parseFloat(latestLocation.speedKph) : null,
        headingDeg: latestLocation.headingDeg,
        recordedAt: latestLocation.recordedAt
      },
      source: "vehicle_location_table"
    });

  } catch (error) {
    console.error('❌ Error getting latest location:', error);
    return res.status(500).json({ message: "Internal server error" });
  }
};

/**
 * Get location history for a vehicle with pagination
 */
const getLocationHistory = async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    const { page = 1, limit = 100, startDate, endDate } = req.query;
    
    console.log('📊 Getting location history for vehicle:', vehicleNumber, { page, limit, startDate, endDate });

    const vehicle = await prisma.vehicle.findUnique({
      where: { vehicleNumber }
    });

    if (!vehicle) {
      return res.status(404).json({ message: "Vehicle not found" });
    }

    // Build where clause for date filtering
    const whereClause = { vehicleId: vehicle.id };
    if (startDate || endDate) {
      whereClause.recordedAt = {};
      if (startDate) whereClause.recordedAt.gte = new Date(startDate);
      if (endDate) whereClause.recordedAt.lte = new Date(endDate);
    }

    // Get total count for pagination
    const totalCount = await prisma.vehicleLocation.count({
      where: whereClause
    });

    // Calculate pagination
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const totalPages = Math.ceil(totalCount / parseInt(limit));

    // Get location history
    const locations = await prisma.vehicleLocation.findMany({
      where: whereClause,
      orderBy: { recordedAt: 'desc' },
      skip,
      take: parseInt(limit),
      select: {
        id: true,
        lat: true,
        lng: true,
        speedKph: true,
        headingDeg: true,
        recordedAt: true
      }
    });

    return res.status(200).json({
      vehicle: {
        id: vehicle.id,
        vehicleNumber: vehicle.vehicleNumber,
        model: vehicle.model,
        type: vehicle.type
      },
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        totalCount,
        totalPages,
        hasNext: parseInt(page) < totalPages,
        hasPrev: parseInt(page) > 1
      },
      locations: locations.map(loc => ({
        lat: parseFloat(loc.lat),
        lng: parseFloat(loc.lng),
        speedKph: loc.speedKph ? parseFloat(loc.speedKph) : null,
        headingDeg: loc.headingDeg,
        recordedAt: loc.recordedAt
      }))
    });

  } catch (error) {
    console.error('❌ Error getting location history:', error);
    return res.status(500).json({ message: "Internal server error" });
  }
};

module.exports = { 
  updateLiveLocation,
  getLatestLocation,
  getLocationHistory
};
