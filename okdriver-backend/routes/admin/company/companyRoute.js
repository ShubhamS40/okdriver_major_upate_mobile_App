const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// GET /api/admin/companies/list
router.get('/list', async (req, res) => {
  try {
    const companies = await prisma.company.findMany({
      include: {
        currentPlan: true,
        _count: { select: { vehicles: true, clients: true } }
      },
      orderBy: { createdAt: 'desc' }
    });

    // For active vehicles count we need a separate aggregate
    const companyIds = companies.map(c => c.id);
    const vehicleGroups = await prisma.vehicle.groupBy({
      by: ['companyId', 'status'],
      where: { companyId: { in: companyIds } },
      _count: { _all: true }
    });

    const activeCountByCompany = new Map();
    vehicleGroups.forEach(g => {
      if (g.status === 'ACTIVE') {
        activeCountByCompany.set(g.companyId, g._count._all);
      }
    });

    const payload = companies.map(c => ({
      id: c.id,
      name: c.name,
      email: c.email,
      phone: '', // not available in schema
      location: '', // not available in schema
      status: c.status === 'ACTIVE' ? 'Active' : (c.status === 'SUSPENDED' ? 'Inactive' : 'Deleted'),
      registrationDate: c.createdAt,
      driversCount: c._count.vehicles,
      activeDriversCount: activeCountByCompany.get(c.id) || 0,
      plan: c.currentPlan ? c.currentPlan.name : '—'
    }));

    res.json({ ok: true, data: payload });
  } catch (err) {
    console.error('admin companies list error:', err);
    res.status(500).json({ ok: false, error: 'internal' });
  }
});

// GET /api/admin/companies/:id
router.get('/:id', async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!id) return res.status(400).json({ ok: false, error: 'invalid id' });

    const company = await prisma.company.findUnique({
      where: { id },
      include: {
        currentPlan: true,
        subscriptions: {
          orderBy: { startAt: 'desc' },
          include: { plan: true }
        },
        vehicles: true,
        clients: true
      }
    });

    if (!company) return res.status(404).json({ ok: false, error: 'not found' });

    // Map to UI-friendly shape
    const activeVehicles = company.vehicles.filter(v => v.status === 'ACTIVE').length;
    const latestSub = company.subscriptions[0];

    const details = {
      id: company.id,
      name: company.name,
      email: company.email,
      phone: '',
      website: '',
      location: '',
      address: '',
      status: company.status === 'ACTIVE' ? 'Active' : (company.status === 'SUSPENDED' ? 'Inactive' : 'Deleted'),
      registeredDate: company.createdAt,
      totalDrivers: company.vehicles.length,
      activeDrivers: activeVehicles,
      plan: company.currentPlan ? company.currentPlan.name : '—',
      subscriptionDetails: latestSub ? {
        planName: latestSub.plan?.name || '—',
        startDate: latestSub.startAt,
        renewalDate: latestSub.endAt,
        amount: String(latestSub.plan?.price || ''),
        billingCycle: latestSub.plan?.billingCycle || '',
        paymentMethod: ''
      } : null,
      vehicles: company.vehicles.map(v => ({ id: v.id, vehicleNumber: v.vehicleNumber, status: v.status })),
      clientsCount: company.clients.length
    };

    // Simple payment history derived from subscriptions (if any)
    const paymentHistory = company.subscriptions.map((s, idx) => ({
      id: idx + 1,
      date: s.startAt,
      amount: String(s.plan?.price || ''),
      status: s.status === 'ACTIVE' ? 'Completed' : 'Failed',
      method: '—'
    }));

    res.json({ ok: true, data: { company: details, paymentHistory } });
  } catch (err) {
    console.error('admin company details error:', err);
    res.status(500).json({ ok: false, error: 'internal' });
  }
});

module.exports = router;


