const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { notifyCompanyResolved, notifyCompanyTicketAction } = require('../../../services/notifications/novu');
const  verifyAdminAuth  = require('../../../middleware/verifyAdminAuth');

// List all company tickets
router.get('/tickets', verifyAdminAuth, async (req, res) => {
  try {
    const tickets = await prisma.helpSupportTicket.findMany({
      orderBy: { createdAt: 'desc' },
      include: { company: { select: { id: true, name: true, email: true } } }
    });
    res.json({ ok: true, data: tickets });
  } catch (e) {
    console.error('admin list tickets error', e);
    res.status(500).json({ ok: false, message: 'internal error' });
  }
});

// Get ticket detail
router.get('/tickets/:id', verifyAdminAuth, async (req, res) => {
  try {
    const id = Number(req.params.id);
    const ticket = await prisma.helpSupportTicket.findUnique({
      where: { id },
      include: { company: { select: { id: true, name: true, email: true } } }
    });
    if (!ticket) return res.status(404).json({ ok: false, message: 'not found' });
    res.json({ ok: true, data: ticket });
  } catch (e) {
    console.error('admin get ticket error', e);
    res.status(500).json({ ok: false, message: 'internal error' });
  }
});

// Update ticket (status/response)
router.put('/tickets/:id', verifyAdminAuth, async (req, res) => {
  try {
    const id = Number(req.params.id);
    const { status, adminResponse } = req.body || {};
    const data = {};
    if (typeof adminResponse === 'string') data.adminResponse = adminResponse;
    if (typeof status === 'string') {
      const up = status.toUpperCase();
      if (['OPEN', 'IN_PROGRESS', 'CLOSED'].includes(up)) {
        data.status = up;
        if (up === 'CLOSED') data.resolvedAt = new Date();
      }
    }
    const updated = await prisma.helpSupportTicket.update({ where: { id }, data });

    // Notify company about any ticket action (status change or response)
    if (status || adminResponse) {
      const company = await prisma.company.findUnique({ 
        where: { id: updated.companyId }, 
        select: { id: true, name: true } 
      });
      
      // Get admin name from token
      const adminName = req.admin?.email?.split('@')[0] || 'Admin';
      
      if (updated.status === 'CLOSED') {
        // Use the existing resolved notification for closed tickets
        await notifyCompanyResolved(updated, company);
      } else {
        // Use the new action notification for other status changes
        await notifyCompanyTicketAction(updated, company, updated.status, adminName);
      }
    }
    
    res.json({ ok: true, data: updated });
  } catch (e) {
    console.error('admin update ticket error', e);
    res.status(500).json({ ok: false, message: 'internal error' });
  }
});

module.exports = router;


