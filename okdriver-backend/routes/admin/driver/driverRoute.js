const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// GET /api/admin/drivers - list individual registered drivers
router.get('/', async (req, res) => {
  try {
    const drivers = await prisma.driver.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        subscriptions: {
          orderBy: { startAt: 'desc' },
          take: 1,
          include: { plan: true }
        }
      }
    });

    const payload = drivers.map(d => {
      const latestSub = d.subscriptions[0];
      const status = latestSub?.status || 'EXPIRED';
      const planName = latestSub?.plan?.name || '—';
      const validity = latestSub ? { startAt: latestSub.startAt, endAt: latestSub.endAt, status } : null;
      return {
        id: d.id,
        name: `${d.firstName} ${d.lastName}`.trim(),
        email: d.email,
        phone: d.phone,
        status: status === 'ACTIVE' ? 'Active' : (status === 'CANCELLED' ? 'Cancelled' : 'Expired'),
        registeredDate: d.createdAt,
        plan: planName,
        validity
      };
    });

    res.json({ ok: true, data: payload });
  } catch (err) {
    console.error('admin drivers list error:', err);
    res.status(500).json({ ok: false, error: 'internal' });
  }
});

// GET /api/admin/drivers/:id - single driver details
router.get('/:id', async (req, res) => {
  try {
    const id = String(req.params.id);
    const driver = await prisma.driver.findUnique({
      where: { id },
      include: {
        subscriptions: { orderBy: { startAt: 'desc' }, include: { plan: true } },
        payments: { orderBy: { createdAt: 'desc' }, include: { plan: true } },
        sessions: true
      }
    });

    if (!driver) return res.status(404).json({ ok: false, error: 'not found' });

    const latestSub = driver.subscriptions[0];
    const details = {
      id: driver.id,
      name: `${driver.firstName} ${driver.lastName}`.trim(),
      email: driver.email,
      phone: driver.phone,
      location: driver.latitude && driver.longitude ? { lat: driver.latitude, lng: driver.longitude } : null,
      status: latestSub?.status === 'ACTIVE' ? 'Active' : (latestSub?.status === 'CANCELLED' ? 'Cancelled' : 'Expired'),
      registeredDate: driver.createdAt,
      plan: latestSub?.plan?.name || '—',
      subscriptionDetails: latestSub ? {
        planName: latestSub.plan?.name || '—',
        startDate: latestSub.startAt,
        renewalDate: latestSub.endAt,
        amount: String(latestSub.plan?.price || ''),
        billingCycle: latestSub.plan?.billingCycle || ''
      } : null,
      sessions: driver.sessions.map(s => ({ id: s.id, isActive: s.isActive, lastActivity: s.lastActivity, expiresAt: s.expiresAt }))
    };

    const paymentHistory = driver.payments.map((p) => ({
      id: p.id,
      date: p.createdAt,
      amount: String(p.amount),
      status: p.status,
      method: '—',
      plan: p.plan?.name || '—'
    }));

    res.json({ ok: true, data: { driver: details, paymentHistory } });
  } catch (err) {
    console.error('admin driver get error:', err);
    res.status(500).json({ ok: false, error: 'internal' });
  }
});

module.exports = router;


