const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const getActiveSubscription = async (req, res) => {
  try {
    const driverId = String(req.query.driverId || req.body.driverId || '');
    if (!driverId) {
      return res
        .status(400)
        .json({ success: false, message: 'driverId is required' });
    }

    const now = new Date();

    // First, expire any subscriptions whose end date has passed but are still marked ACTIVE
    await prisma.driverSubscription.updateMany({
      where: {
        driverId,
        status: 'ACTIVE',
        endAt: { lt: now },
      },
      data: { status: 'EXPIRED' },
    });

    // Fetch the latest active subscription that is still within its validity window
    const sub = await prisma.driverSubscription.findFirst({
      where: {
        driverId,
        status: 'ACTIVE',
        endAt: { gte: now },
      },
      orderBy: { endAt: 'desc' },
      include: { plan: true },
    });

    if (!sub) {
      return res.json({
        success: true,
        active: false,
        message: 'No active subscription found for this driver',
      });
    }

    const remainingMs = new Date(sub.endAt).getTime() - now.getTime();
    const remainingDays = Math.max(
      0,
      Math.ceil(remainingMs / (1000 * 60 * 60 * 24))
    );

    return res.json({
      success: true,
      active: true,
      subscription: {
        id: sub.id,
        startAt: sub.startAt,
        endAt: sub.endAt,
        status: sub.status,
        paymentRef: sub.paymentRef,
        remainingDays,
        plan: {
          id: sub.plan.id,
          name: sub.plan.name,
          price: sub.plan.price,
          durationDays: sub.plan.durationDays,
          billingCycle: sub.plan.billingCycle,
          description: sub.plan.description,
          benefits: sub.plan.benefits,
          storageLimitGB: sub.plan.storageLimitGB,
        },
      },
    });
  } catch (e) {
    console.error('getActiveSubscription error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
};

module.exports = { getActiveSubscription };


