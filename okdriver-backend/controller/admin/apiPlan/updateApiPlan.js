const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const updateApiPlan = async (req, res) => {
  try {
    const { id } = req.params;
    if (!id || isNaN(Number(id))) return res.status(400).json({ ok: false, error: 'invalid id' });

    const { name, description, price, currency, features, isActive } = req.body || {};

    const data = {};
    if (name !== undefined) data.name = name;
    if (description !== undefined) data.description = description;
    if (price !== undefined) data.price = price;
    if (currency !== undefined) data.currency = currency || 'INR';
    if (features !== undefined) data.features = Array.isArray(features) ? features : [];
    if (isActive !== undefined) data.isActive = !!isActive;

    const updated = await prisma.apiPlan.update({ where: { id: Number(id) }, data });
    res.json({ ok: true, data: updated });
  } catch (err) {
    console.error('updateApiPlan error:', err);
    res.status(500).json({ ok: false, error: 'internal' });
  }
};

module.exports = { updateApiPlan };


