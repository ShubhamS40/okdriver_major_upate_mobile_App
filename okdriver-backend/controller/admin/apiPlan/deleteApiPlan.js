const { PrismaClient, Prisma } = require('@prisma/client');
const prisma = new PrismaClient();

const deleteApiPlan = async (req, res) => {
  // Resolve id outside try so it's available in catch branches
  const rawId = req.params?.id ?? req.body?.id;
  const idNum = Number(rawId);

  if (!rawId || Number.isNaN(idNum)) {
    return res.status(400).json({ ok: false, error: 'invalid_id', message: 'Valid numeric id is required' });
  }

  try {
    // Check if plan is referenced
    const subsCount = await prisma.userApiSubscription.count({ where: { planId: idNum } }).catch(() => 0);

    if (subsCount > 0) {
      // Perform cascading delete in a transaction: remove subscriptions then the plan
      await prisma.$transaction([
        prisma.userApiSubscription.deleteMany({ where: { planId: idNum } }),
        prisma.apiPlan.delete({ where: { id: idNum } })
      ]);
      return res.json({ ok: true, deleted: true, cascaded: true, removedSubscriptions: subsCount });
    }

    // No references; delete plan directly
    await prisma.apiPlan.delete({ where: { id: idNum } });
    return res.json({ ok: true, deleted: true, cascaded: false });
  } catch (err) {
    console.error('deleteApiPlan error:', err);

    // Handle Prisma known errors
    if (err instanceof Prisma.PrismaClientKnownRequestError) {
      // Record not found
      if (err.code === 'P2025') {
        return res.status(404).json({ ok: false, error: 'not_found', message: 'API Plan not found' });
      }
      // Foreign key constraint failed on some unexpected relation.
      if (err.code === 'P2003') {
        return res.status(409).json({ ok: false, error: 'constraint_violation', message: 'Plan is in use and could not be deleted.' });
      }
    }

    return res.status(500).json({ ok: false, error: 'internal', message: 'Internal server error' });
  }
};

module.exports = { deleteApiPlan };


