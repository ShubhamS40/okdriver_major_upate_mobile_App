const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const getApiPlans = async (_req, res) => {
  try {
    const plans = await prisma.apiPlan.findMany({ orderBy: { price: 'asc' } });
    res.json({ ok: true, data: plans });
  } catch (err) {
    console.error('getApiPlans error:', err);
    res.status(500).json({ ok: false, error: 'internal' });
  }
};

module.exports = { getApiPlans };


