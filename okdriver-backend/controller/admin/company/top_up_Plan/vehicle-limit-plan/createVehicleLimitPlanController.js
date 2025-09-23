const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Create Vehicle Limit Plan
exports.createVehicleLimitPlan = async (req, res) => {
  try {
    const { name, description, price, vehicleCount } = req.body;

    // Validation
    if (!name || !price || !vehicleCount) {
      return res.status(400).json({
        success: false,
        message: 'Name, price, and vehicle count are required'
      });
    }

    if (vehicleCount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Vehicle count must be greater than 0'
      });
    }

    // Create the vehicle limit plan
    const vehicleLimitPlan = await prisma.companyPlan.create({
      data: {
        name,
        description: description || null,
        price: parseFloat(price),
        vehicleLimit: parseInt(vehicleCount),
        planType: 'VEHICLE_LIMIT',
        keyAdvantages: [],
        isActive: true
      }
    });

    res.status(201).json({
      success: true,
      message: 'Vehicle limit plan created successfully',
      data: vehicleLimitPlan
    });

  } catch (error) {
    console.error('Error creating vehicle limit plan:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create vehicle limit plan',
      error: error.message
    });
  }
};
