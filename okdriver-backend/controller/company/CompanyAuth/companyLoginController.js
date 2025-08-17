const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const prisma = new PrismaClient();

const loginCompany = async (req, res) => {
  try {
    const { email, password } = req.body;

    // 1️⃣ Find company by email
    const company = await prisma.company.findUnique({ where: { email } });
    if (!company) {
      return res.status(404).json({ message: "Company not found" });
    }

    // 2️⃣ Check password
    const isMatch = await bcrypt.compare(password, company.password);
    if (!isMatch) {
      return res.status(400).json({ message: "Invalid credentials" });
    }

    // 3️⃣ Generate JWT token
    const token = jwt.sign({ id: company.id }, process.env.JWT_SECRET, {
      expiresIn: '7d'
    });

    // 4️⃣ Check if company has an active subscription
    const activeSubscription = await prisma.subscription.findFirst({
      where: {
        companyId: company.id,
        status: 'ACTIVE', // ✅ use enum value from your schema
        endAt: { gte: new Date() } // ✅ checks if subscription is still valid
      },
      include: { plan: true }
    });

    if (!activeSubscription) {
      // ❌ No active subscription → send available plans for selection
      const plans = await prisma.plan.findMany({
        orderBy: { createdAt: 'desc' }
      });

      return res.json({
        token,
        company,
        hasActivePlan: false,
        plans
      });
    }

    // ✅ Has active subscription → allow dashboard access
    return res.json({
      token,
      company,
      hasActivePlan: true,
      activePlan: activeSubscription
    });

  } catch (err) {
    console.error('Login Error:', err);
    res.status(500).json({ error: err.message });
  }
};

module.exports = { loginCompany };
