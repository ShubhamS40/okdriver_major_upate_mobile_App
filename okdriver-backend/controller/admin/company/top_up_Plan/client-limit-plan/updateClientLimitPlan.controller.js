const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Update Client Limit Plan
exports.updateClientLimitPlan = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description, price, clientCount, isActive } = req.body;

    const updatedPlan = await prisma.companyPlan.update({
      where: { id: parseInt(id) },
      data: {
        ...(name && { name }),
        ...(description !== undefined && { description }),
        ...(price && { price: parseFloat(price) }),
        ...(clientCount && { clientLimit: parseInt(clientCount) }),
        ...(isActive !== undefined && { isActive })
      }
    });

    res.status(200).json({
      success: true,
      message: 'Client limit plan updated successfully',
      data: updatedPlan
    });

  } catch (error) {
    console.error('Error updating client limit plan:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update client limit plan',
      error: error.message
    });
  }
};
