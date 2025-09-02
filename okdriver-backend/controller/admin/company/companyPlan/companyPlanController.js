const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const selectPlan = async (req, res) => {
  try {
    const companyId = req.company.id;
    const { planId } = req.body;

    // Plan check karo
    const plan = await prisma.plan.findUnique({ where: { id: planId } });
    if (!plan) {
      return res.status(404).json({ message: "Plan not found" });
    }

    // Active subscription check karo
    const existing = await prisma.subscription.findFirst({
      where: {
        companyId,
        status: 'ACTIVE',
        endAt: { gte: new Date() }
      }
    });

    if (existing) {
      return res.status(400).json({ message: "You already have an active plan" });
    }

    // End date calculate karo
    const endDate = new Date();
    endDate.setDate(endDate.getDate() + plan.durationDays);

    // Subscription create karo
    const subscription = await prisma.subscription.create({
      data: {
        companyId,
        planId,
        endAt: endDate,
        status: 'ACTIVE'
      }
    });

    // Company ke current plan update karo
    await prisma.company.update({
      where: { id: companyId },
      data: {
        currentPlanId: planId,
        subscriptionExpiresAt: endDate
      }
    });

    res.json({
      message: "Plan purchased successfully",
      subscription
    });
  } catch (err) {
    console.error('Plan Selection Error:', err);
    res.status(500).json({ error: err.message });
  }
};

module.exports = { selectPlan };
