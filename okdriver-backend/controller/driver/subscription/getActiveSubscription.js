const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const getActiveSubscription = async (req, res) => {
  try {
    const driverId = String(req.query.driverId || req.body.driverId || '');
    if (!driverId) return res.status(400).json({ success: false, message: 'driverId is required' });

    const sub = await prisma.driverSubscription.findFirst({
      where: { driverId, status: 'ACTIVE' },
      orderBy: { endAt: 'desc' },
      include: { plan: true },
    });

    if (!sub) return res.json({ success: true, active: false });

    return res.json({
      success: true,
      active: true,
      subscription: {
        id: sub.id,
        startAt: sub.startAt,
        endAt: sub.endAt,
        status: sub.status,
        paymentRef: sub.paymentRef,
        plan: {
          id: sub.plan.id,
          name: sub.plan.name,
          price: sub.plan.price,
          durationDays: sub.plan.durationDays,
          billingCycle: sub.plan.billingCycle,
          description: sub.plan.description,
          benefits: sub.plan.benefits,
          storageLimitGB: sub.plan.storageLimitGB,
        }
      }
    });
  } catch (e) {
    console.error('getActiveSubscription error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
};

module.exports = { getActiveSubscription };


