const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Get vehicle chat history for company
 */
const getVehicleChatHistory = async (req, res) => {
  try {
    const { vehicleId } = req.params;
    const { limit = 50, offset = 0 } = req.query;
    const companyId = req.company.id;

    // Verify the vehicle belongs to the company
    const vehicle = await prisma.vehicle.findFirst({
      where: { 
        id: parseInt(vehicleId),
        companyId: companyId
      }
    });

    if (!vehicle) {
      return res.status(404).json({
        success: false,
        message: 'Vehicle not found or access denied'
      });
    }

    // Get chat messages (only last 24 hours)
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    
    const messages = await prisma.vehicleChat.findMany({
      where: { 
        vehicleId: parseInt(vehicleId),
        companyId: companyId,
        createdAt: {
          gte: oneDayAgo
        }
      },
      orderBy: { createdAt: 'desc' },
      take: parseInt(limit),
      skip: parseInt(offset)
    });

    res.json({
      success: true,
      data: messages
    });

  } catch (error) {
    console.error('Get vehicle chat history error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Send message to vehicle (company to driver)
 */
const sendMessageToVehicle = async (req, res) => {
  try {
    const { vehicleId } = req.params;
    const { message, attachmentUrl } = req.body;
    const companyId = req.company.id;

    if (!message || !message.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Message is required'
      });
    }

    // Verify the vehicle belongs to the company
    const vehicle = await prisma.vehicle.findFirst({
      where: { 
        id: parseInt(vehicleId),
        companyId: companyId
      }
    });

    if (!vehicle) {
      return res.status(404).json({
        success: false,
        message: 'Vehicle not found or access denied'
      });
    }

    // Create chat message
    const chatMessage = await prisma.vehicleChat.create({
      data: {
        vehicleId: parseInt(vehicleId),
        companyId: companyId,
        senderType: 'COMPANY',
        message: message.trim(),
        attachmentUrl: attachmentUrl || null,
        isRead: false
      }
    });

    res.json({
      success: true,
      data: chatMessage,
      message: 'Message sent successfully'
    });

  } catch (error) {
    console.error('Send message to vehicle error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Mark messages as read
 */
const markMessagesAsRead = async (req, res) => {
  try {
    const { vehicleId } = req.params;
    const { messageIds } = req.body;
    const companyId = req.company.id;

    if (!messageIds || !Array.isArray(messageIds)) {
      return res.status(400).json({
        success: false,
        message: 'Message IDs array is required'
      });
    }

    // Verify the vehicle belongs to the company
    const vehicle = await prisma.vehicle.findFirst({
      where: { 
        id: parseInt(vehicleId),
        companyId: companyId
      }
    });

    if (!vehicle) {
      return res.status(404).json({
        success: false,
        message: 'Vehicle not found or access denied'
      });
    }

    // Mark messages as read
    await prisma.vehicleChat.updateMany({
      where: {
        id: { in: messageIds },
        vehicleId: parseInt(vehicleId),
        companyId: companyId,
        senderType: 'DRIVER' // Only mark driver messages as read
      },
      data: {
        isRead: true
      }
    });

    res.json({
      success: true,
      message: 'Messages marked as read'
    });

  } catch (error) {
    console.error('Mark messages as read error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Get unread message count for vehicle
 */
const getUnreadCount = async (req, res) => {
  try {
    const { vehicleId } = req.params;
    const companyId = req.company.id;

    // Verify the vehicle belongs to the company
    const vehicle = await prisma.vehicle.findFirst({
      where: { 
        id: parseInt(vehicleId),
        companyId: companyId
      }
    });

    if (!vehicle) {
      return res.status(404).json({
        success: false,
        message: 'Vehicle not found or access denied'
      });
    }

    // Get unread count
    const unreadCount = await prisma.vehicleChat.count({
      where: {
        vehicleId: parseInt(vehicleId),
        companyId: companyId,
        senderType: 'DRIVER',
        isRead: false
      }
    });

    res.json({
      success: true,
      data: { unreadCount }
    });

  } catch (error) {
    console.error('Get unread count error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Clean up old messages (older than 24 hours)
 */
const cleanupOldMessages = async (req, res) => {
  try {
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    
    const result = await prisma.vehicleChat.deleteMany({
      where: {
        createdAt: {
          lt: oneDayAgo
        }
      }
    });

    res.json({
      success: true,
      message: `Cleaned up ${result.count} old messages`,
      deletedCount: result.count
    });

  } catch (error) {
    console.error('Cleanup old messages error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

module.exports = {
  getVehicleChatHistory,
  sendMessageToVehicle,
  markMessagesAsRead,
  getUnreadCount,
  cleanupOldMessages
};
