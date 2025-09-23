const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Create Client Limit Plan
exports.createClientLimitPlan = async (req, res) => {
  try {
    const { name, description, price, clientCount } = req.body;

    if (!name || !price || !clientCount) {
      return res.status(400).json({
        success: false,
        message: 'Name, price, and client count are required'
      });
    }

    if (clientCount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Client count must be greater than 0'
      });
    }

    const clientLimitPlan = await prisma.companyPlan.create({
      data: {
        name,
        description: description || null,
        price: parseFloat(price),
        clientLimit: parseInt(clientCount),
        planType: 'CLIENT_LIMIT',
        keyAdvantages: [],
        isActive: true
      }
    });

    res.status(201).json({
      success: true,
      message: 'Client limit plan created successfully',
      data: clientLimitPlan
    });

  } catch (error) {
    console.error('Error creating client limit plan:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create client limit plan',
      error: error.message
    });
  }
};
