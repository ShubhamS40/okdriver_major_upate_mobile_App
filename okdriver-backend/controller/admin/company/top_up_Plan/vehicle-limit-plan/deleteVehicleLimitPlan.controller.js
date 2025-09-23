const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Delete Vehicle Limit Plan (Soft Delete)
exports.deleteVehicleLimitPlan = async (req, res) => {
  try {
    const { id } = req.params;

    // Check if plan has any active top-ups
    const activeTopUps = await prisma.vehicleLimitTopUp.findMany({
      where: {
        planId: parseInt(id),
        status: 'ACTIVE'
      }
    });

    if (activeTopUps.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'Cannot delete plan with active top-ups'
      });
    }

    // Soft delete by setting isActive = false
    await prisma.companyPlan.update({
      where: { id: parseInt(id) },
      data: { isActive: false }
    });

    res.status(200).json({
      success: true,
      message: 'Vehicle limit plan deleted successfully'
    });

  } catch (error) {
    console.error('Error deleting vehicle limit plan:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete vehicle limit plan',
      error: error.message
    });
  }
};
