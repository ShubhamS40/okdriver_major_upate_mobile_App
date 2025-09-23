const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

let io;

// Initialize Socket.IO server
function initializeSocketServer(server) {
  io = new Server(server, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST']
    }
  });

  // Authentication middleware for socket connections
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token;
      
      if (!token) {
        return next(new Error('Authentication token is required'));
      }
      
      // Verify token and determine user type (company or driver)
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      
      if (!decoded.id) {
        return next(new Error('Invalid authentication token'));
      }
      
      // Store user info in socket
      socket.userId = decoded.id;
      socket.userType = decoded.type; // 'company' or 'driver'
      socket.vehicleId = decoded.vehicleId; // For drivers
      
      next();
    } catch (error) {
      console.error('Socket authentication error:', error.message);
      next(new Error('Authentication failed'));
    }
  });

  // Handle connections
  io.on('connection', (socket) => {
    console.log(`User connected: ${socket.id} (${socket.userType})`);
    
    // Join appropriate rooms based on user type
    if (socket.userType === 'company') {
      // Company joins its own room
      socket.join(`company:${socket.userId}`);
      console.log(`Company ${socket.userId} joined company room`);
    } else if (socket.userType === 'driver' && socket.vehicleId) {
      // Driver joins vehicle room
      socket.join(`vehicle:${socket.vehicleId}`);
      console.log(`Driver joined vehicle:${socket.vehicleId} room`);
    }
    
    // Handle disconnection
    socket.on('disconnect', () => {
      console.log(`User disconnected: ${socket.id}`);
    });
    
    // Chat functionality is handled in index.js
  });

  return io;
}

// Get the Socket.IO instance
function getIO() {
  if (!io) {
    throw new Error('Socket.IO has not been initialized');
  }
  return io;
}

module.exports = {
  initializeSocketServer,
  getIO
};