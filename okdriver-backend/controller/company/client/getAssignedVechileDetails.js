const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Get vehicles assigned to this client with enhanced location data
 */
const getAssignedVehicles = async (req, res) => {
  try {
    const clientId = req.user?.clientId; // set by auth middleware
    if (!clientId) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const accesses = await prisma.clientVehicleAccess.findMany({
      where: { clientId },
      include: {
        vehicle: {
          include: {
            company: {
              select: {
                id: true,
                name: true
              }
            },
            locations: {
              take: 1,
              orderBy: { recordedAt: 'desc' }
            }
          }
        }
      }
    });

    const vehiclesWithLocation = accesses.map(a => {
      const vehicle = a.vehicle;
      const latestLocation = vehicle.locations[0];
      
      return {
        accessId: a.id,
        vehicleId: vehicle.id,
        vehicleNumber: vehicle.vehicleNumber,
        model: vehicle.model,
        type: vehicle.type,
        status: vehicle.status,
        companyId: vehicle.companyId,
        companyName: vehicle.company.name,
        latestLocation: latestLocation ? {
          id: latestLocation.id,
          lat: parseFloat(latestLocation.lat),
          lng: parseFloat(latestLocation.lng),
          speedKph: latestLocation.speedKph ? parseFloat(latestLocation.speedKph) : null,
          headingDeg: latestLocation.headingDeg,
          recordedAt: latestLocation.recordedAt
        } : null,
        // Use cached last known location if available
        lastKnownLocation: vehicle.lastLat && vehicle.lastLng ? {
          lat: parseFloat(vehicle.lastLat),
          lng: parseFloat(vehicle.lastLng),
          recordedAt: vehicle.lastLocationAt
        } : null,
        // Determine which location to use (prioritize latest from locations table)
        currentLocation: latestLocation ? {
          lat: parseFloat(latestLocation.lat),
          lng: parseFloat(latestLocation.lng),
          speedKph: latestLocation.speedKph ? parseFloat(latestLocation.speedKph) : null,
          headingDeg: latestLocation.headingDeg,
          recordedAt: latestLocation.recordedAt
        } : (vehicle.lastLat && vehicle.lastLng ? {
          lat: parseFloat(vehicle.lastLat),
          lng: parseFloat(vehicle.lastLng),
          recordedAt: vehicle.lastLocationAt
        } : null)
      };
    });

    return res.status(200).json({
      success: true,
      message: "Assigned vehicles retrieved successfully",
      data: vehiclesWithLocation,
      count: vehiclesWithLocation.length
    });
  } catch (error) {
    console.error("Error fetching assigned vehicles:", error);
    return res.status(500).json({ 
      success: false,
      message: "Internal Server Error",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * Get detailed location history for a specific assigned vehicle
 */
const getVehicleLocationHistory = async (req, res) => {
  try {
    const clientId = req.user?.clientId;
    const { vehicleId } = req.params;
    const { page = 1, limit = 100, startDate, endDate } = req.query;

    if (!clientId) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    // Verify client has access to this vehicle
    const access = await prisma.clientVehicleAccess.findFirst({
      where: { 
        clientId: parseInt(clientId),
        vehicleId: parseInt(vehicleId)
      }
    });

    if (!access) {
      return res.status(403).json({ message: "Access denied to this vehicle" });
    }

    // Build where clause for date filtering
    const whereClause = { vehicleId: parseInt(vehicleId) };
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

    // Get vehicle details
    const vehicle = await prisma.vehicle.findUnique({
      where: { id: parseInt(vehicleId) },
      select: {
        id: true,
        vehicleNumber: true,
        model: true,
        type: true,
        status: true
      }
    });

    return res.status(200).json({
      success: true,
      message: "Vehicle location history retrieved successfully",
      data: {
        vehicle,
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
      }
    });

  } catch (error) {
    console.error("Error fetching vehicle location history:", error);
    return res.status(500).json({ 
      success: false,
      message: "Internal Server Error",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * Get real-time location for assigned vehicles (for WebSocket updates)
 */
const getAssignedVehiclesRealTime = async (req, res) => {
  try {
    const clientId = req.user?.clientId;
    if (!clientId) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const accesses = await prisma.clientVehicleAccess.findMany({
      where: { clientId: parseInt(clientId) },
      include: {
        vehicle: {
          select: {
            id: true,
            vehicleNumber: true,
            model: true,
            type: true,
            status: true,
            lastLat: true,
            lastLng: true,
            lastLocationAt: true
          }
        }
      }
    });

    const realTimeData = accesses.map(a => {
      const vehicle = a.vehicle;
      return {
        vehicleId: vehicle.id,
        vehicleNumber: vehicle.vehicleNumber,
        model: vehicle.model,
        type: vehicle.type,
        status: vehicle.status,
        currentLocation: vehicle.lastLat && vehicle.lastLng ? {
          lat: parseFloat(vehicle.lastLat),
          lng: parseFloat(vehicle.lastLng),
          recordedAt: vehicle.lastLocationAt
        } : null,
        lastUpdate: vehicle.lastLocationAt
      };
    });

    return res.status(200).json({
      success: true,
      message: "Real-time vehicle data retrieved successfully",
      data: realTimeData,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error("Error fetching real-time vehicle data:", error);
    return res.status(500).json({ 
      success: false,
      message: "Internal Server Error",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

module.exports = { 
  getAssignedVehicles,
  getVehicleLocationHistory,
  getAssignedVehiclesRealTime
};