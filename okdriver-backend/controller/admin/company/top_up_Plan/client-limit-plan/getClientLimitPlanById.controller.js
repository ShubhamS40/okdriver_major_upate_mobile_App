const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Get Client Limit Plan By ID
exports.getClientLimitPlanById = async (req, res) => {
  try {
    const { id } = req.params;

    const clientLimitPlan = await prisma.companyPlan.findUnique({
      where: {
        id: parseInt(id),
        planType: 'CLIENT_LIMIT'
      }
    });

    if (!clientLimitPlan) {
      return res.status(404).json({
        success: false,
        message: 'Client limit plan not found'
      });
    }

    res.status(200).json({
      success: true,
      data: clientLimitPlan
    });

  } catch (error) {
    console.error('Error fetching client limit plan:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch client limit plan',
      error: error.message
    });
  }
};