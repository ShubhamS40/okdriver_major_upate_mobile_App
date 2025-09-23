const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Delete Client Limit Plan (Soft Delete)
exports.deleteClientLimitPlan = async (req, res) => {
  try {
    const { id } = req.params;

    const activeTopUps = await prisma.clientLimitTopUp.findMany({
      where: { planId: parseInt(id), status: 'ACTIVE' }
    });

    if (activeTopUps.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'Cannot delete plan with active top-ups'
      });
    }

    await prisma.companyPlan.update({
      where: { id: parseInt(id) },
      data: { isActive: false }
    });

    res.status(200).json({
      success: true,
      message: 'Client limit plan deleted successfully'
    });

  } catch (error) {
    console.error('Error deleting client limit plan:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete client limit plan',
      error: error.message
    });
  }
};
