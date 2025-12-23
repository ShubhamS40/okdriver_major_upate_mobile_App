const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Create a new API plan
const createApiPlan = async (req, res) => {
  try {
    const { name, description, price, currency, features, isActive, daysValidity } = req.body || {};

    if (!name || price === undefined || !daysValidity) {
      return res.status(400).json({ ok: false, error: 'name, price, and daysValidity are required' });
    }

    const plan = await prisma.apiPlan.create({
      data: {
        name,
        description: description || null,
        price,
        currency: currency || 'INR',
        features: Array.isArray(features) ? features : [],
        isActive: typeof isActive === 'boolean' ? isActive : true,
        daysValidity,
      },
    });

    res.status(201).json({ ok: true, data: plan });
  } catch (err) {
    console.error('createApiPlan error:', err);
    res.status(500).json({ ok: false, error: 'internal' });
  }
};

module.exports = { createApiPlan };


