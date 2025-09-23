const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Middleware to allow either a company token or a driver (vehicle) token
// Sets req.company when possible, and req.vehicle for driver tokens
module.exports = async function companyOrVehicleAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization || '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!token) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // If token belongs to company user
    if (decoded && (decoded.type === 'company' || decoded.role === 'COMPANY')) {
      const company = await prisma.company.findUnique({ where: { id: decoded.id } });
      if (!company) return res.status(401).json({ message: 'Company not found' });
      req.company = { id: company.id, name: company.name };
      return next();
    }

    // If token belongs to driver/vehicle
    if (decoded && (decoded.type === 'driver' || decoded.role === 'DRIVER')) {
      const vehicle = await prisma.vehicle.findUnique({ where: { id: decoded.vehicleId } });
      if (!vehicle) return res.status(401).json({ message: 'Vehicle not found' });
      // Provide company context from vehicle
      req.company = { id: vehicle.companyId };
      req.vehicle = { id: vehicle.id };
      return next();
    }

    return res.status(401).json({ message: 'Unauthorized' });
  } catch (e) {
    console.error('Auth error (companyOrVehicleAuth):', e.message);
    return res.status(401).json({ message: 'Unauthorized' });
  }
};


