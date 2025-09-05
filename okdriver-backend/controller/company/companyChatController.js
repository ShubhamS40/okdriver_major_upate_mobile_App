/**
 * Controller for company chat functionality
 * Handles REST API endpoints for chat operations
 */

const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { getIO } = require('../../socket');

// Send message to a vehicle by company
const sendMessageToVehicleByCompany = async (req, res) => {
  try {
    const { vehicleId, message, attachmentUrl } = req.body;
    const companyId = req.company.id;
    
    if (!vehicleId || !message) {
      return res.status(400).json({ success: false, message: 'Vehicle ID and message are required' });
    }
    
    // Check if vehicle exists and belongs to the company
    const vehicle = await prisma.vehicle.findFirst({
      where: {
        id: vehicleId,
        companyId
      }
    });
    
    if (!vehicle) {
      return res.status(404).json({ success: false, message: 'Vehicle not found or does not belong to your company' });
    }
    
    // Save message to database
    const savedMessage = await prisma.vehicleChat.create({
      data: {
        message,
        attachmentUrl,
        vehicleId,
        companyId,
        senderType: 'COMPANY',
        isRead: false
      }
    });
    
    // Send real-time notification via Socket.IO
    const io = getIO();
    io.to(`vehicle:${vehicleId}`).emit('new_message', {
      id: savedMessage.id,
      message: savedMessage.message,
      attachmentUrl: savedMessage.attachmentUrl,
      vehicleId: savedMessage.vehicleId,
      companyId: savedMessage.companyId,
      senderType: savedMessage.senderType,
      isRead: savedMessage.isRead,
      createdAt: savedMessage.createdAt
    });
    
    return res.status(201).json({
      success: true,
      message: 'Message sent successfully',
      data: savedMessage
    });
  } catch (error) {
    console.error('Error sending message to vehicle:', error);
    return res.status(500).json({ success: false, message: 'Failed to send message' });
  }
};

// Send message to a client in the vehicle context (optional)
const sendMessageToClientByCompany = async (req, res) => {
  try {
    const { vehicleId, clientId, message, attachmentUrl } = req.body;
    const companyId = req.company.id;
    
    if (!vehicleId || !clientId || !message) {
      return res.status(400).json({ 
        success: false, 
        message: 'Vehicle ID, client ID, and message are required' 
      });
    }
    
    // Check if vehicle exists and belongs to the company
    const vehicle = await prisma.vehicle.findFirst({
      where: {
        id: vehicleId,
        companyId
      }
    });
    
    if (!vehicle) {
      return res.status(404).json({ 
        success: false, 
        message: 'Vehicle not found or does not belong to your company' 
      });
    }
    
    // Check if client exists
    const client = await prisma.client.findUnique({
      where: { id: clientId }
    });
    
    if (!client) {
      return res.status(404).json({ success: false, message: 'Client not found' });
    }
    
    // Save message to database
    const savedMessage = await prisma.vehicleChat.create({
      data: {
        message,
        attachmentUrl,
        vehicleId,
        companyId,
        clientId,
        senderType: 'COMPANY',
        isRead: false
      }
    });
    
    // Send real-time notification via Socket.IO
    const io = getIO();
    io.to(`vehicle:${vehicleId}`).emit('new_message', {
      id: savedMessage.id,
      message: savedMessage.message,
      attachmentUrl: savedMessage.attachmentUrl,
      vehicleId: savedMessage.vehicleId,
      companyId: savedMessage.companyId,
      clientId: savedMessage.clientId,
      senderType: savedMessage.senderType,
      isRead: savedMessage.isRead,
      createdAt: savedMessage.createdAt
    });
    
    return res.status(201).json({
      success: true,
      message: 'Message sent successfully',
      data: savedMessage
    });
  } catch (error) {
    console.error('Error sending message to client:', error);
    return res.status(500).json({ success: false, message: 'Failed to send message' });
  }
};

// Get vehicle chat history for company
const getVehicleChatsForCompany = async (req, res) => {
  try {
    const { vehicleId } = req.params;
    const companyId = req.company.id;
    const { limit = 50, offset = 0 } = req.query;
    
    // Check if vehicle exists and belongs to the company
    const vehicle = await prisma.vehicle.findFirst({
      where: {
        id: vehicleId,
        companyId
      }
    });
    
    if (!vehicle) {
      return res.status(404).json({ 
        success: false, 
        message: 'Vehicle not found or does not belong to your company' 
      });
    }
    
    // Get chat messages
    const messages = await prisma.vehicleChat.findMany({
      where: {
        vehicleId,
        companyId
      },
      orderBy: {
        createdAt: 'desc'
      },
      take: parseInt(limit),
      skip: parseInt(offset)
    });
    
    // Get total count for pagination
    const totalCount = await prisma.vehicleChat.count({
      where: {
        vehicleId,
        companyId
      }
    });
    
    return res.status(200).json({
      success: true,
      data: {
        messages,
        pagination: {
          total: totalCount,
          limit: parseInt(limit),
          offset: parseInt(offset)
        }
      }
    });
  } catch (error) {
    console.error('Error fetching vehicle chats:', error);
    return res.status(500).json({ success: false, message: 'Failed to fetch chat history' });
  }
};

module.exports = {
  sendMessageToVehicleByCompany,
  sendMessageToClientByCompany,
  getVehicleChatsForCompany
};