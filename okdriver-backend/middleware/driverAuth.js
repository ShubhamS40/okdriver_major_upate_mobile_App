const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

const authenticateDriver = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix

    // Find active session
    const session = await prisma.driverSession.findFirst({
      where: {
        token: token,
        isActive: true,
        expiresAt: {
          gt: new Date()
        }
      },
      include: {
        driver: true
      }
    });

    if (!session) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }

    // Update last activity
    await prisma.driverSession.update({
      where: { id: session.id },
      data: { lastActivity: new Date() }
    });

    // Attach driver info to request
    req.driver = session.driver;
    req.session = session;

    next();
  } catch (error) {
    console.error('Authentication error:', error);
    res.status(500).json({ error: 'Authentication failed' });
  }
};

module.exports = { authenticateDriver }; 