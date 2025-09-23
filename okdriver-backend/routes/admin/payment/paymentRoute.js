const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// GET /api/admin/payment/company-transactions
// Returns recent company subscription transactions
router.get('/company-transactions', async (req, res) => {
  try {
    const { limit = 100 } = req.query;
    const subs = await prisma.companySubscription.findMany({
      take: Number(limit),
      orderBy: { startAt: 'desc' },
      include: {
        company: true,
        plan: true
      }
    });

    const data = subs.map(s => ({
      id: s.id,
      transactionId: `SUB-${String(s.id).padStart(5, '0')}`,
      customer: s.company?.name || '—',
      customerId: s.companyId,
      plan: s.plan?.name || '—',
      amount: s.plan?.price?.toString() || '0',
      date: s.startAt,
      status: s.status === 'ACTIVE' ? 'Completed' : (s.status === 'CANCELLED' ? 'Cancelled' : 'Completed'),
      billingCycle: s.plan?.billingCycle || '—'
    }));

    res.json({ ok: true, data });
  } catch (err) {
    console.error('admin payment list error:', err);
    res.status(500).json({ ok: false, error: 'internal' });
  }
});

module.exports = router;


