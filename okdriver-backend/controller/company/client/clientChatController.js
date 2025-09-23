const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// @desc    Get chat history for a specific client (last 24 hours)
// @route   GET /api/company/clients/:clientId/chat-history
// @access  Private (Company or Client)
const getClientChatHistory = async (req, res) => {
  try {
    const { clientId } = req.params;
    const { limit = 50, offset = 0 } = req.query;

    // Get company ID from request (set by middleware)
    const companyId = req.company.id;

    // Calculate 24 hours ago
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    console.log(`📨 Getting chat history for client ${clientId}, company ${companyId}`);
    console.log(`📨 Limit: ${limit}, Offset: ${offset}`);
    console.log(`📨 Since: ${oneDayAgo.toISOString()}`);
    
    console.log('🔍 Request object:', {
      company: req.company,
      client: req.client,
      userType: req.userType
    });
    
    if (!req.company) {
      return res.status(401).json({
        success: false,
        message: 'Company information not found in request'
      });
    }

    // Verify client belongs to company
    const client = await prisma.client.findFirst({
      where: {
        id: parseInt(clientId),
        companyId: companyId,
      },
    });

    if (!client) {
      return res.status(404).json({
        success: false,
        message: 'Client not found or does not belong to company',
      });
    }

    console.log('🔍 Prisma client:', prisma);
    console.log('🔍 Prisma clientChat:', prisma.clientChat);
    
    if (!prisma.clientChat) {
      return res.status(500).json({
        success: false,
        message: 'ClientChat model not found in Prisma schema'
      });
    }
    
    const messages = await prisma.clientChat.findMany({
      where: { 
        clientId: parseInt(clientId),
        companyId: companyId,
        createdAt: {
          gte: oneDayAgo
        }
      },
      orderBy: { createdAt: 'desc' },
      take: parseInt(limit),
      skip: parseInt(offset)
    });

    console.log(`✅ Found ${messages.length} messages for client ${clientId}`);

    res.json({
      success: true,
      data: messages,
      count: messages.length,
    });
  } catch (error) {
    console.error('Error getting client chat history:', error);
    res.status(500).json({
      success: false,
      message: 'Internal Server Error',
    });
  }
};

// @desc    Send message from company to client
// @route   POST /api/company/clients/:clientId/send-message
// @access  Private (Company)
const sendCompanyMessageToClient = async (req, res) => {
  try {
    const { clientId } = req.params;
    const { message } = req.body;

    if (!message || message.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Message content is required',
      });
    }

    // Get company ID from request (set by middleware)
    const companyId = req.company.id;

    console.log(`📤 Sending message from company ${companyId} to client ${clientId}`);
    console.log(`📤 Message: ${message}`);

    // Verify client belongs to company
    const client = await prisma.client.findFirst({
      where: {
        id: parseInt(clientId),
        companyId: companyId,
      },
    });

    if (!client) {
      return res.status(404).json({
        success: false,
        message: 'Client not found or does not belong to company',
      });
    }

    // Create message in database
    const newMessage = await prisma.clientChat.create({
      data: {
        clientId: parseInt(clientId),
        companyId: companyId,
        message: message.trim(),
        senderType: 'COMPANY',
        isRead: false,
      },
    });

    console.log(`✅ Message created with ID: ${newMessage.id}`);

    // Emit to socket for real-time delivery (both client and company rooms)
    if (req.app.get('io')) {
      // Notify client device
      req.app.get('io').to(`client_${clientId}`).emit('new_message', {
        id: newMessage.id,
        message: newMessage.message,
        senderType: newMessage.senderType,
        createdAt: newMessage.createdAt,
        clientId: newMessage.clientId,
        companyId: newMessage.companyId,
      });
      // Echo back to company dashboard so it updates without reload
      req.app.get('io').to(`company:${companyId}`).emit('new_message', {
        id: newMessage.id,
        message: newMessage.message,
        senderType: newMessage.senderType,
        createdAt: newMessage.createdAt,
        clientId: newMessage.clientId,
        companyId: newMessage.companyId,
      });
      console.log(`📡 Message emitted to client_${clientId} and company:${companyId} rooms`);
    }

    res.json({
      success: true,
      message: 'Message sent successfully',
      data: newMessage,
    });
  } catch (error) {
    console.error('Error sending company message to client:', error);
    res.status(500).json({
      success: false,
      message: 'Internal Server Error',
    });
  }
};

// @desc    Send message from client to company
// @route   POST /api/company/clients/:clientId/send-message
// @access  Private (Client)
const sendClientMessage = async (req, res) => {
  try {
    const { clientId } = req.params;
    const { message } = req.body;

    if (!message || message.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Message content is required',
      });
    }

    // Get company ID from request (set by middleware)
    const companyId = req.company.id;

    console.log(`📤 Sending message from client ${clientId} to company ${companyId}`);
    console.log(`📤 Message: ${message}`);

    // Verify client belongs to company
    const client = await prisma.client.findFirst({
      where: {
        id: parseInt(clientId),
        companyId: companyId,
      },
    });

    if (!client) {
      return res.status(404).json({
        success: false,
        message: 'Client not found or does not belong to company',
      });
    }

    // Create message
    const newMessage = await prisma.clientChat.create({
      data: {
        clientId: parseInt(clientId),
        companyId: companyId,
        message: message.trim(),
        senderType: 'CLIENT',
        isRead: false,
      },
    });

    console.log(`✅ Message created with ID: ${newMessage.id}`);

    // Emit to socket for real-time delivery (both company and client rooms)
    if (req.app.get('io')) {
      // Notify company dashboard/agents
      req.app.get('io').to(`company_${companyId}`).emit('new_message', {
        id: newMessage.id,
        message: newMessage.message,
        senderType: newMessage.senderType,
        createdAt: newMessage.createdAt,
        clientId: newMessage.clientId,
        companyId: newMessage.companyId,
      });
      // Echo to client device so they also see their own sent message
      req.app.get('io').to(`client_${clientId}`).emit('new_message', {
        id: newMessage.id,
        message: newMessage.message,
        senderType: newMessage.senderType,
        createdAt: newMessage.createdAt,
        clientId: newMessage.clientId,
        companyId: newMessage.companyId,
      });
      console.log(`📡 Message emitted to company_${companyId} and client_${clientId} rooms`);
    }

    res.json({
      success: true,
      message: 'Message sent successfully',
      data: newMessage,
    });
  } catch (error) {
    console.error('Error sending client message:', error);
    res.status(500).json({
      success: false,
      message: 'Internal Server Error',
    });
  }
};

// @desc    Mark messages as read
// @route   PUT /api/company/clients/:clientId/mark-read
// @access  Private (Client)
const markClientMessagesAsRead = async (req, res) => {
  try {
    const { clientId } = req.params;
    const { messageIds } = req.body;

    if (!messageIds || !Array.isArray(messageIds) || messageIds.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Message IDs array is required',
      });
    }

    // Get company ID from request (set by middleware)
    const companyId = req.company.id;

    console.log(`👀 Marking messages as read for client ${clientId}`);
    console.log(`👀 Message IDs: ${messageIds}`);

    // Verify client belongs to company
    const client = await prisma.client.findFirst({
      where: {
        id: parseInt(clientId),
        companyId: companyId,
      },
    });

    if (!client) {
      return res.status(404).json({
        success: false,
        message: 'Client not found or does not belong to company',
      });
    }

    // Mark messages as read
    const result = await prisma.clientChat.updateMany({
      where: {
        id: { in: messageIds },
        clientId: parseInt(clientId),
        companyId: companyId,
        senderType: 'COMPANY', // Only mark company messages as read
      },
      data: {
        isRead: true,
      },
    });

    console.log(`✅ Marked ${result.count} messages as read`);

    res.json({
      success: true,
      message: 'Messages marked as read',
      count: result.count,
    });
  } catch (error) {
    console.error('Error marking client messages as read:', error);
    res.status(500).json({
      success: false,
      message: 'Internal Server Error',
    });
  }
};

// @desc    Get unread message count for client
// @route   GET /api/company/clients/:clientId/unread-count
// @access  Private (Client)
const getClientUnreadCount = async (req, res) => {
  try {
    const { clientId } = req.params;

    // Get company ID from request (set by middleware)
    const companyId = req.company.id;

    console.log(`📊 Getting unread count for client ${clientId}`);

    // Verify client belongs to company
    const client = await prisma.client.findFirst({
      where: {
        id: parseInt(clientId),
        companyId: companyId,
      },
    });

    if (!client) {
      return res.status(404).json({
        success: false,
        message: 'Client not found or does not belong to company',
      });
    }

    // Calculate 24 hours ago
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const unreadCount = await prisma.clientChat.count({
      where: {
        clientId: parseInt(clientId),
        companyId: companyId,
        senderType: 'COMPANY',
        isRead: false,
        createdAt: {
          gte: oneDayAgo
        }
      },
    });

    console.log(`📊 Unread count for client ${clientId}: ${unreadCount}`);

    res.json({
      success: true,
      count: unreadCount,
    });
  } catch (error) {
    console.error('Error getting client unread count:', error);
    res.status(500).json({
      success: false,
      message: 'Internal Server Error',
    });
  }
};

module.exports = {
  getClientChatHistory,
  sendCompanyMessageToClient,
  sendClientMessage,
  markClientMessagesAsRead,
  getClientUnreadCount,
};
