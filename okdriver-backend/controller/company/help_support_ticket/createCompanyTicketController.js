const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { notifyAdminNewTicket, notifyAdminsIndividually } = require('../../../services/notifications/novu');

// POST /api/company/help-support/tickets
async function createCompanyTicket(req, res) {
  try {
    const companyId = req.company?.id;
    if (!companyId) return res.status(401).json({ ok: false, message: 'unauthorized' });

    const { subject, description, priority } = req.body || {};
    if (!subject || !description) {
      return res.status(400).json({ ok: false, message: 'subject and description are required' });
    }

    const normalizedPriority = (priority || 'MEDIUM').toString().toUpperCase();
    const allowed = new Set(['LOW', 'MEDIUM', 'HIGH']);
    const priorityEnum = allowed.has(normalizedPriority) ? normalizedPriority : 'MEDIUM';

    const ticket = await prisma.helpSupportTicket.create({
      data: {
        companyId: Number(companyId),
        subject: String(subject).trim(),
        description: String(description).trim(),
        priority: priorityEnum
      }
    });

    // Notify admins via Novu (best-effort)
    try {
      const company = await prisma.company.findUnique({ where: { id: Number(companyId) }, select: { id: true, name: true } });
      await notifyAdminNewTicket(ticket, company);
      // Optional individual notifications (can be heavy; causes 504 sometimes)
      if (process.env.NOVU_INDIVIDUAL === 'true') {
        const admins = await prisma.admin.findMany({ select: { id: true, email: true } });
        await notifyAdminsIndividually(ticket, admins, company);
      }
    } catch (_) {}

    return res.status(201).json({ ok: true, data: ticket });
  } catch (e) {
    console.error('createCompanyTicket error', e);
    return res.status(500).json({ ok: false, message: 'internal error' });
  }
}

module.exports = { createCompanyTicket };
// GET /api/company/help-support/tickets (company's own)
async function listCompanyTickets(req, res) {
  try {
    const companyId = req.company?.id;
    if (!companyId) return res.status(401).json({ ok: false, message: 'unauthorized' });
    const tickets = await prisma.helpSupportTicket.findMany({
      where: { companyId: Number(companyId) },
      orderBy: { createdAt: 'desc' }
    });
    res.json({ ok: true, data: tickets });
  } catch (e) {
    console.error('listCompanyTickets error', e);
    res.status(500).json({ ok: false, message: 'internal error' });
  }
}

// GET /api/company/help-support/tickets/:id
async function getCompanyTicket(req, res) {
  try {
    const companyId = req.company?.id;
    const id = Number(req.params.id);
    if (!companyId) return res.status(401).json({ ok: false, message: 'unauthorized' });
    const ticket = await prisma.helpSupportTicket.findFirst({
      where: { id, companyId: Number(companyId) }
    });
    if (!ticket) return res.status(404).json({ ok: false, message: 'not found' });
    res.json({ ok: true, data: ticket });
  } catch (e) {
    console.error('getCompanyTicket error', e);
    res.status(500).json({ ok: false, message: 'internal error' });
  }
}

module.exports.listCompanyTickets = listCompanyTickets;
module.exports.getCompanyTicket = getCompanyTicket;


