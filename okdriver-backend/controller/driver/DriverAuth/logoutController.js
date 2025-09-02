const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

exports.logout = async (req, res) => {
  try {
    const sessionId = req.session.id;

    // Deactivate the current session
    await prisma.driverSession.update({
      where: { id: sessionId },
      data: { isActive: false }
    });

    res.status(200).json({
      message: 'Logged out successfully'
    });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({ error: 'Logout failed' });
  }
};

exports.getCurrentDriver = async (req, res) => {
  try {
    const driver = req.driver;
    
    res.status(200).json({
      success: true,
      driver: driver
    });
  } catch (error) {
    console.error('Get current driver error:', error);
    res.status(500).json({ error: 'Failed to get driver data' });
  }
}; 