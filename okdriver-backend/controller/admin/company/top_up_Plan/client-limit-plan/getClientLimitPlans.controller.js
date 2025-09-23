const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Get All Client Limit Plans
exports.getClientLimitPlans = async (req, res) => {
  try {
    const clientLimitPlans = await prisma.companyPlan.findMany({
      where: { planType: 'CLIENT_LIMIT', isActive: true },
      orderBy: { createdAt: 'desc' }
    });

    res.status(200).json({ success: true, data: clientLimitPlans });

  } catch (error) {
    console.error('Error fetching client limit plans:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch client limit plans',
      error: error.message
    });
  }
};
