const { PrismaClient } = require('@prisma/client');
const jwt = require('jsonwebtoken');

const prisma = new PrismaClient();

const verifyCompanyPlan = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(" ")[1];
    if (!token) return res.status(401).json({ message: "No token provided" });

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;

    const company = await prisma.company.findUnique({
      where: { id: decoded.id },
      include: { plan: true }
    });

    if (!company) return res.status(404).json({ message: "Company not found" });
    if (!company.plan) return res.status(403).json({ message: "Please select a plan" });

    const planStart = new Date(company.plan.startDate);
    const planExpiry = new Date(planStart);
    planExpiry.setDate(planStart.getDate() + company.plan.durationDays);

    if (new Date() > planExpiry) {
      return res.status(403).json({ message: "Your plan has expired" });
    }

    next();
  } catch (err) {
    res.status(401).json({ message: "Invalid token" });
  }
};

module.exports = { verifyCompanyPlan };
