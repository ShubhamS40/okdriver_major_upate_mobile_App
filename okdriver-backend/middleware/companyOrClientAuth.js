const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Middleware to allow either a company token or a client token
// Sets req.company when possible, and req.client for client tokens
module.exports = async function companyOrClientAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization || '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!token) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // If token belongs to company user
    if (!decoded.clientId && (decoded.companyId || decoded.id)) {
      const companyId = decoded.companyId || decoded.id;
      const company = await prisma.company.findUnique({
        where: { id: companyId },
      });
      if (!company) {
        return res.status(401).json({ message: 'Company not found' });
      }
      req.company = company;
      req.userType = 'company';
      return next();
    }

    // If token belongs to client
    if (decoded.clientId) {
      const client = await prisma.client.findUnique({
        where: { id: decoded.clientId },
        include: { company: true },
      });
      if (!client) {
        return res.status(401).json({ message: 'Client not found' });
      }
      req.client = client;
      req.company = client.company; // Set company from client relationship
      req.userType = 'client';
      return next();
    }

    return res.status(401).json({ message: 'Invalid token' });
  } catch (error) {
    console.error('Auth middleware error:', error);
    return res.status(401).json({ message: 'Invalid token' });
  }
};
