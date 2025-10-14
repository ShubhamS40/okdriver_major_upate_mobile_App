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

// Permanently delete current driver's account and cascade related data
exports.deleteAccount = async (req, res) => {
  try {
    const driverId = req.driver.id;

    // End current session first (best-effort)
    try {
      await prisma.driverSession.update({
        where: { id: req.session.id },
        data: { isActive: false }
      });
    } catch (_) {}

    // Delete the driver; relations are set to Cascade in Prisma schema
    await prisma.driver.delete({
      where: { id: driverId }
    });

    return res.status(200).json({ success: true, message: 'Account deleted successfully' });
  } catch (error) {
    console.error('Delete account error:', error);
    return res.status(500).json({ success: false, error: 'Failed to delete account' });
  }
};