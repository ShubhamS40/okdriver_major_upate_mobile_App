const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Get Vehicle Limit Plan By ID
exports.getVehicleLimitPlanById = async (req, res) => {
  try {
    const { id } = req.params;

    const vehicleLimitPlan = await prisma.companyPlan.findUnique({
      where: {
        id: parseInt(id),
        planType: 'VEHICLE_LIMIT'
      }
    });

    if (!vehicleLimitPlan) {
      return res.status(404).json({
        success: false,
        message: 'Vehicle limit plan not found'
      });
    }

    res.status(200).json({
      success: true,
      data: vehicleLimitPlan
    });

  } catch (error) {
    console.error('Error fetching vehicle limit plan:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch vehicle limit plan',
      error: error.message
    });
  }
};