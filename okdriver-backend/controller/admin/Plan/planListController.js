
const {PrismaClient} = require('@prisma/client');

const prisma = new PrismaClient()


// List all plans
const listPlans = async (req, res) => {
  try {
    const plans = await prisma.plan.findMany({
      orderBy: { createdAt: 'desc' }
    });
    res.json(plans);
  } catch (error) {
    console.error('List Plan Error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { listPlans };
