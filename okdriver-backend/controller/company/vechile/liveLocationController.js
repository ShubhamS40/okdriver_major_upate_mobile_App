const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Update live location for a vehicle
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
    
    console.log('📊 Request body:', JSON.stringify(req.body, null, 2));

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

    // Find vehicle by vehicleNumber
    const vehicle = await prisma.vehicle.findUnique({
      where: { vehicleNumber }
    });

    if (!vehicle) {
      console.log('❌ Vehicle not found:', vehicleNumber);
      return res.status(404).json({ message: "Vehicle not found" });
    }

    console.log('✅ Vehicle found:', { id: vehicle.id, companyId: vehicle.companyId });

    // Store location in VehicleLocation table
    const locationRecord = await prisma.vehicleLocation.create({
      data: {
        vehicleId: vehicle.id,
        lat: parseFloat(latitude),
        lng: parseFloat(longitude),
        speedKph: speedKph ? parseFloat(speedKph) : null,
        headingDeg: headingDeg ? parseInt(headingDeg) : null,
        recordedAt: new Date()
      }
    });

    console.log('💾 Location saved to database:', {
      locationId: locationRecord.id,
      vehicleId: locationRecord.vehicleId,
      timestamp: locationRecord.recordedAt
    });

    // Optional: Update vehicle's last known location (if you want to add this field to Vehicle model)
    // await prisma.vehicle.update({
    //   where: { id: vehicle.id },
    //   data: { 
    //     lastLat: parseFloat(latitude),
    //     lastLng: parseFloat(longitude),
    //     lastLocationAt: new Date()
    //   }
    // });

    return res.status(200).json({
      message: "Location updated successfully",
      location: {
        id: locationRecord.id,
        vehicleId: locationRecord.vehicleId,
        lat: locationRecord.lat,
        lng: locationRecord.lng,
        speedKph: locationRecord.speedKph,
        headingDeg: locationRecord.headingDeg,
        recordedAt: locationRecord.recordedAt
      }
    });

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
 */
const getLatestLocation = async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    
    console.log('🔍 Getting latest location for vehicle:', vehicleNumber);

    const vehicle = await prisma.vehicle.findUnique({
      where: { vehicleNumber }
    });

    if (!vehicle) {
      return res.status(404).json({ message: "Vehicle not found" });
    }

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
        lat: latestLocation.lat,
        lng: latestLocation.lng,
        speedKph: latestLocation.speedKph,
        headingDeg: latestLocation.headingDeg,
        recordedAt: latestLocation.recordedAt
      }
    });

  } catch (error) {
    console.error('❌ Error getting latest location:', error);
    return res.status(500).json({ message: "Internal server error" });
  }
};

module.exports = { 
  updateLiveLocation,
  getLatestLocation
};
