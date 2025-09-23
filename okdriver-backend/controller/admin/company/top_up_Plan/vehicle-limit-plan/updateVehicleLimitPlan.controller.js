const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Update Vehicle Limit Plan
exports.updateVehicleLimitPlan = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description, price, vehicleCount, isActive } = req.body;

    const updatedPlan = await prisma.companyPlan.update({
      where: { id: parseInt(id) },
      data: {
        ...(name && { name }),
        ...(description !== undefined && { description }),
        ...(price && { price: parseFloat(price) }),
        ...(vehicleCount && { vehicleLimit: parseInt(vehicleCount) }),
        ...(isActive !== undefined && { isActive })
      }
    });

    res.status(200).json({
      success: true,
      message: 'Vehicle limit plan updated successfully',
      data: updatedPlan
    });

  } catch (error) {
    console.error('Error updating vehicle limit plan:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update vehicle limit plan',
      error: error.message
    });
  }
};
