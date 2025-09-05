const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Get vehicle chat history for company
 */
const getVehicleChatHistory = async (req, res) => {
  try {
    const { vehicleId } = req.params;
    const { limit = 50, offset = 0 } = req.query;
    const companyId = req.user.id;

    // Verify the vehicle belongs to the company
    const vehicle = await prisma.vehicle.findFirst({
      where: { 
        id: parseInt(vehicleId),
        companyId: companyId
      }
    });

    if (!vehicle) {
      return res.status(404).json({
        success: false,
        message: 'Vehicle not found or access denied'
      });
    }

    // Get chat messages
    const messages = await prisma.vehicleChat.findMany({
      where: { 
        vehicleId: parseInt(vehicleId),
        companyId: companyId
      },
      orderBy: { createdAt: 'asc' },
      take: parseInt(limit),
      skip: parseInt(offset)
    });

    res.json({
      success: true,
      data: messages
    });

  } catch (error) {
    console.error('Get vehicle chat history error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

module.exports = {
  getVehicleChatHistory
};
