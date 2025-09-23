const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Get All Vehicle Limit Plans
exports.getVehicleLimitPlans = async (req, res) => {
  try {
    const vehicleLimitPlans = await prisma.companyPlan.findMany({
      where: {
        planType: 'VEHICLE_LIMIT',
        isActive: true
      },
      orderBy: {
        createdAt: 'desc'
      }
    });

    res.status(200).json({
      success: true,
      data: vehicleLimitPlans
    });

  } catch (error) {
    console.error('Error fetching vehicle limit plans:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch vehicle limit plans',
      error: error.message
    });
  }
};
