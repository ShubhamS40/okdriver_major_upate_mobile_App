const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const verifyCompanyAuth = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(" ")[1];
    if (!token) return res.status(401).json({ message: "Not authorized, token missing" });

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const company = await prisma.company.findUnique({ where: { id: decoded.id } });
    if (!company) return res.status(401).json({ message: "Company not found" });

    req.company = company;
    next();
  } catch (err) {
    console.error("Auth Middleware Error:", err);
    res.status(401).json({ message: "Invalid or expired token" });
  }
};

module.exports = { verifyCompanyAuth };
