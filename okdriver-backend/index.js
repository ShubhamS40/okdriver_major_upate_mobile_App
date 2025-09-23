const express = require('express');
const dotenv = require('dotenv');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

// Kafka/Location imports
const { initializeProducer, initializeConsumer } = require('./config/kafka');
const locationProcessor = require('./services/locationProcessor');
const webSocketService = require('./services/websocketService');

// Driver routes
const otpRoutes = require('./routes/driver/DriverAuth/otpRoutes');
const driverRegistration = require('./routes/driver/DriverAuth/driverRegistration');
const driverAuthRoutes = require('./routes/driver/DriverAuth/driverAuth');

// Company routes
const companyRoutes = require('./routes/company/CompanyAuthRoutes/companyAuthRoute');
const companyChatRoutes = require('./routes/company/companyChatRoutes');

dotenv.config();

const app = express();
const http = require('http').createServer(app);
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const jwt = require('jsonwebtoken');

// Initialize Socket.IO - DON'T call initializeSocketServer yet
const { Server } = require('socket.io');
const io = new Server(http, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Middlewares
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logger
app.use((req, res, next) => {
  console.log(`[REQ] ${req.method} ${req.originalUrl}`);
  next();
});

// Static audio
const audioDir = path.join(__dirname, 'audio');
if (!fs.existsSync(audioDir)) {
  fs.mkdirSync(audioDir, { recursive: true });
}
app.use('/audio', express.static(audioDir));

// Routes
app.use('/api/driver', otpRoutes);
app.use('/api/drivers', driverRegistration);
app.use('/api/driver/auth', driverAuthRoutes);

// Company routes
app.use('/api/company', companyRoutes);
app.use('/api/company/help-support', require('./routes/company/help_support_ticket/createCompanyTicketRoute'));
app.use('/api/admin/auth', require('./routes/admin/adminAuth/adminAuthRoute'));
app.use('/api/assistant', require('./routes/driver/DriverVoiceAssistant/driverVoiceAssistant'));

// WEBSITE ALL ROUTE
console.log('🔄 Loading company client routes...');
app.use('/api/company/clients', require('./routes/company/client/clientRoute'));
console.log('✅ Company client routes mounted at /api/company/clients');

app.use('/api/company/vehicles', require('./routes/company/vechile/companyVehicleRoute'));
app.use('/api/company', require('./routes/company/companyChatRoutes'));

// Admin routes
app.use('/api/admin/driverplan', require('./routes/admin/driver/driverPlan/driverPlanRoute'));
app.use('/api/admin/company/top-up-plan/vehicle-limit', require('./routes/admin/company/top-up-plan/vehicleLimitPlan/vehicleLimitRoutes'));
app.use('/api/admin/company/top-up-plan/client-limit', require('./routes/admin/company/top-up-plan/clientLimitPlan/clientLimit.routes'));
app.use('/api/admin/companyplan', require('./routes/admin/company/companyPlan/planRoute'));
app.use('/api/admin/companies', require('./routes/admin/company/companyRoute'));
app.use('/api/admin/payment', require('./routes/admin/payment/paymentRoute'));
app.use('/api/admin/support', require('./routes/admin/support/ticketRoute'));

// Health check
app.get('/', (req, res) => {
  res.send('Ok Driver + Company Backend Services are Running Successfully');
});

// ---------------- SOCKET.IO REALTIME CHAT & LOCATION ----------------

// Authentication for sockets
io.use(async (socket, next) => {
  try {
    const { token, role, vehicleId } = socket.handshake.auth || {};
    if (!token) return next(new Error('unauthorized'));

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    if (role === 'COMPANY') {
      const company = await prisma.company.findUnique({ where: { id: decoded.id } });
      if (!company) return next(new Error('unauthorized'));
      socket.data.companyId = company.id;
      socket.data.driver = false; // Explicitly set driver to false
    } else if (role === 'CLIENT') {
      socket.data.clientId = decoded.clientId;
      socket.data.driver = false; // Explicitly set driver to false
    } else if (role === 'DRIVER') {
      socket.data.driver = true;
      socket.data.vehicleId = decoded.vehicleId;
      socket.data.companyId = decoded.companyId; // Keep companyId for room joining
    }
    
    if (vehicleId) socket.data.vehicleId = Number(vehicleId);
    next();
  } catch (e) {
    console.error("❌ Socket auth failed:", e.message);
    next(new Error('unauthorized'));
  }
});

// Connection
io.on('connection', (socket) => {
  let room = undefined;
  
  console.log(`🔗 New socket connection: ${socket.id}`);
  console.log(`🔗 Socket data:`, socket.data);
  console.log(`🔗 Auth handshake:`, socket.handshake.auth);
  
  if (socket.data.vehicleId) {
    room = `vehicle:${socket.data.vehicleId}`;
    socket.join(room);
    console.log(`🚗 Vehicle ${socket.data.vehicleId} joined vehicle room`);
  }
  
  if (socket.data.companyId && socket.data.driver === false) {
    const companyRoom = `company:${socket.data.companyId}`;
    socket.join(companyRoom);
    console.log(`🏢 Company ${socket.data.companyId} joined company room`);
  }

  // Join client-specific room if this is a client socket
  if (socket.data.clientId) {
    const clientRoom = `client_${socket.data.clientId}`;
    socket.join(clientRoom);
    console.log(`👤 Client ${socket.data.clientId} joined room ${clientRoom}`);
  }

  console.log(`🔗 Socket connected: ${socket.id}, joined room: ${room}`);

  // ===== CHAT FUNCTIONALITY =====
  // Send chat message (vehicle/company/client -> vehicle/company/client)
  socket.on('chat:send', async (payload, cb) => {
    try {
      const { vehicleId, message, attachmentUrl, clientId: targetClientId } = payload || {};
      const vid = Number(vehicleId || socket.data.vehicleId);
      if (!vid || !message) return cb && cb({ ok: false, error: 'missing fields' });

      console.log(`📨 Received chat:send from socket ${socket.id}`);
      console.log(`📨 Vehicle ID: ${vid}, Message: ${message}`);
      console.log(`📨 Socket data:`, {
        companyId: socket.data.companyId,
        driver: socket.data.driver,
        vehicleId: socket.data.vehicleId,
        clientId: socket.data.clientId
      });

      // Get vehicle info to find company
      const vehicle = await prisma.vehicle.findUnique({
        where: { id: vid },
        select: { companyId: true }
      });

      if (!vehicle) return cb && cb({ ok: false, error: 'vehicle not found' });

      // Sender identify and create VehicleChat data
      let data = { 
        vehicleId: vid, 
        companyId: vehicle.companyId,
        message: message.trim(), 
        senderType: 'DRIVER',
        attachmentUrl: attachmentUrl || null,
        isRead: false
      };
      
      // Determine sender type
      if (socket.data.driver && !socket.data.companyId) {
        data.senderType = 'DRIVER';
        console.log(`📤 Message from DRIVER (vehicle ${vid})`);
      } else if (socket.data.companyId && !socket.data.driver) {
        data.senderType = 'COMPANY';
        console.log(`📤 Message from COMPANY (${socket.data.companyId})`);
      } else if (socket.data.clientId) {
        data.senderType = 'CLIENT';
        console.log(`📤 Message from CLIENT (${socket.data.clientId})`);
      } else {
        // Default to DRIVER if we can't determine
        data.senderType = 'DRIVER';
        console.log(`📤 Message from DRIVER (default, vehicle ${vid})`);
      }

      // If sender is CLIENT, ensure the client has access to this vehicle
      if (socket.data.clientId) {
        const access = await prisma.clientVehicleAccess.count({
          where: { clientId: socket.data.clientId, vehicleId: vid }
        });
        if (!access) {
          return cb && cb({ ok: false, error: 'unauthorized: no access to vehicle' });
        }
      }

      // Save chat in VehicleChat table
      const chat = await prisma.vehicleChat.create({ data });
      console.log(`💾 Message saved to database: ${chat.senderType} - ${chat.message}`);

      // Broadcast to room with enhanced message data
      const messageData = {
        id: chat.id,
        message: chat.message,
        senderType: chat.senderType,
        createdAt: chat.createdAt,
        attachmentUrl: chat.attachmentUrl,
        isRead: chat.isRead,
        vehicleId: chat.vehicleId,
        companyId: chat.companyId
      };

      // Send to vehicle room (driver will receive)
      io.to(`vehicle:${vid}`).emit('new_message', messageData);
      
      // Send to company room (company will receive)
      io.to(`company:${vehicle.companyId}`).emit('new_message', messageData);

      // If sender is CLIENT, also emit back to that client's room so their UI updates immediately
      if (socket.data.clientId) {
        io.to(`client_${socket.data.clientId}`).emit('new_message', messageData);
      }

      // If sender is DRIVER and a specific target client is provided, emit to that client's room
      if (socket.data.driver && targetClientId) {
        io.to(`client_${Number(targetClientId)}`).emit('new_message', messageData);
      }
      
      console.log(`📤 Message broadcasted: ${chat.senderType} -> Vehicle:${vid}, Company:${vehicle.companyId}`);

      cb && cb({ ok: true, chat: messageData });
    } catch (err) {
      console.error('chat:send error', err);
      cb && cb({ ok: false, error: 'internal' });
    }
  });

  // Fetch chat history
  socket.on('chat:history', async (vehicleId, cb) => {
    try {
      const vid = Number(vehicleId || socket.data.vehicleId);
      if (!vid) return cb && cb({ ok: false, error: 'missing vehicleId' });

      // Get only last 24 hours of messages
      const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

      const chats = await prisma.vehicleChat.findMany({
        where: { 
          vehicleId: vid,
          createdAt: {
            gte: oneDayAgo
          }
        },
        orderBy: { createdAt: 'asc' }
      });

      cb && cb({ ok: true, chats });
    } catch (err) {
      console.error('chat:history error', err);
      cb && cb({ ok: false, error: 'internal' });
    }
  });

  // Mark messages as read
  socket.on('mark_messages_read', async (payload, cb) => {
    try {
      const { messageIds, vehicleId } = payload || {};
      const vid = Number(vehicleId || socket.data.vehicleId);
      
      if (!vid || !messageIds || !Array.isArray(messageIds)) {
        return cb && cb({ ok: false, error: 'missing fields' });
      }

      await prisma.vehicleChat.updateMany({
        where: {
          id: { in: messageIds },
          vehicleId: vid,
          senderType: socket.data.companyId ? 'DRIVER' : 'COMPANY'
        },
        data: {
          isRead: true
        }
      });

      cb && cb({ ok: true });
    } catch (err) {
      console.error('mark_messages_read error', err);
      cb && cb({ ok: false, error: 'internal' });
    }
  });

  // Get unread count
  socket.on('get_unread_count', async (payload, cb) => {
    try {
      const { vehicleId } = payload || {};
      const vid = Number(vehicleId || socket.data.vehicleId);
      
      if (!vid) return cb && cb({ ok: false, error: 'missing vehicleId' });

      const unreadCount = await prisma.vehicleChat.count({
        where: {
          vehicleId: vid,
          senderType: socket.data.companyId ? 'DRIVER' : 'COMPANY',
          isRead: false
        }
      });

      cb && cb({ ok: true, unreadCount });
    } catch (err) {
      console.error('get_unread_count error', err);
      cb && cb({ ok: false, error: 'internal' });
    }
  });

  // ===== LOCATION FUNCTIONALITY =====
  // Handle location updates
  socket.on('location:update', async (payload, cb) => {
    try {
      const { vehicleId, latitude, longitude, speed, heading, timestamp } = payload || {};
      const vid = Number(vehicleId || socket.data.vehicleId);
      
      if (!vid || !latitude || !longitude) {
        return cb && cb({ ok: false, error: 'missing location data' });
      }

      // Only drivers can send location updates
      if (!socket.data.driver) {
        return cb && cb({ ok: false, error: 'unauthorized: only drivers can send location' });
      }

      const locationData = {
        vehicleId: vid,
        latitude,
        longitude,
        speed: speed || 0,
        heading: heading || 0,
        timestamp: timestamp || new Date().toISOString()
      };

      // Broadcast location to company room for real-time tracking
      const vehicle = await prisma.vehicle.findUnique({
        where: { id: vid },
        select: { companyId: true }
      });

      if (vehicle) {
        io.to(`company:${vehicle.companyId}`).emit('location:update', locationData);
        
        // Also emit to any clients who have access to this vehicle
        const clientAccess = await prisma.clientVehicleAccess.findMany({
          where: { vehicleId: vid },
          select: { clientId: true }
        });

        for (const access of clientAccess) {
          io.to(`client_${access.clientId}`).emit('location:update', locationData);
        }
      }

      console.log(`📍 Location update broadcasted for vehicle ${vid}`);
      cb && cb({ ok: true });
    } catch (err) {
      console.error('location:update error', err);
      cb && cb({ ok: false, error: 'internal' });
    }
  });

  // Subscribe to vehicle location updates
  socket.on('location:subscribe', async (payload, cb) => {
    try {
      const { vehicleId } = payload || {};
      const vid = Number(vehicleId);
      
      if (!vid) {
        return cb && cb({ ok: false, error: 'missing vehicleId' });
      }

      // Check if user has permission to track this vehicle
      let hasPermission = false;

      if (socket.data.companyId && !socket.data.driver) {
        // Company can track their own vehicles
        const vehicle = await prisma.vehicle.findFirst({
          where: { id: vid, companyId: socket.data.companyId }
        });
        hasPermission = !!vehicle;
      } else if (socket.data.clientId) {
        // Client can track vehicles they have access to
        const access = await prisma.clientVehicleAccess.findFirst({
          where: { clientId: socket.data.clientId, vehicleId: vid }
        });
        hasPermission = !!access;
      }

      if (!hasPermission) {
        return cb && cb({ ok: false, error: 'unauthorized: no permission to track this vehicle' });
      }

      // Join location room for this vehicle
      const locationRoom = `location:${vid}`;
      socket.join(locationRoom);
      console.log(`📍 Socket ${socket.id} subscribed to location updates for vehicle ${vid}`);
      
      cb && cb({ ok: true });
    } catch (err) {
      console.error('location:subscribe error', err);
      cb && cb({ ok: false, error: 'internal' });
    }
  });

  socket.on('disconnect', () => {
    console.log(`❌ Socket disconnected: ${socket.id}`);
  });
});

// Scheduled cleanup for old messages (every hour)
setInterval(async () => {
  try {
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    
    const result = await prisma.vehicleChat.deleteMany({
      where: {
        createdAt: {
          lt: oneDayAgo
        }
      }
    });

    if (result.count > 0) {
      console.log(`🧹 Cleaned up ${result.count} old chat messages`);
    }
  } catch (error) {
    console.error('❌ Error cleaning up old messages:', error);
  }
}, 60 * 60 * 1000); // Run every hour

// Start server
const PORT = process.env.PORT || 5000;
http.listen(PORT, async () => {
  console.log(`✅ Server + Socket.IO started on port ${PORT}`);
  console.log(`🧹 Message cleanup scheduled every hour`);
  
  // DON'T initialize separate WebSocket service - it conflicts with Socket.IO chat
  // Instead, use the integrated location handlers in the Socket.IO server above
  
  // Start Kafka consumer and location processor for DB persistence
  try {
    // Ensure producer is connected for controllers to send messages
    await initializeProducer();
    await initializeConsumer();
    await locationProcessor.start();
    console.log('✅ Kafka consumer + Location processor running');
  } catch (err) {
    console.error('❌ Failed to start Kafka consumer/location processor:', err);
  }
});