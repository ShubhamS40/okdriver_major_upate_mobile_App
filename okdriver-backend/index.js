const express = require('express');
const dotenv = require('dotenv');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

// Driver routes
const otpRoutes = require('./routes/driver/DriverAuth/otpRoutes');
const driverRegistration = require('./routes/driver/DriverAuth/driverRegistration');
const driverAuthRoutes = require('./routes/driver/DriverAuth/driverAuth');

// Company routes
const companyRoutes = require('./routes/company/CompanyAuthRoutes/companyAuthRoute');

dotenv.config();
const app = express();
const http = require('http').createServer(app);
const { Server } = require('socket.io');
const io = new Server(http, {
  cors: { origin: '*', methods: ['GET','POST'] }
});
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const jwt = require('jsonwebtoken');

// Middlewares
app.use(cors());
app.use(express.json());

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
app.use('/api/admin/auth', require('./routes/admin/adminAuth/adminAuthRoute'));
app.use('/api/assistant', require('./routes/driver/DriverVoiceAssistant/driverVoiceAssistant'));

// WEBSITE ALL ROUTE
console.log('🔄 Loading company client routes...');
app.use('/api/company/clients', require('./routes/company/client/clientRoute'));
console.log('✅ Company client routes mounted at /api/company/clients');

app.use('/api/company/vehicles', require('./routes/company/vechile/companyVehicleRoute'));
app.use('/api/company', require('./routes/company/companyChatRoutes'));

// Admin  routes
app.use('/api/admin/driverplan', require('./routes/admin/driver/driverPlan/driverPlanRoute'));
app.use('/api/admin/companyplan', require('./routes/admin/company/companyPlan/planRoute'));

// Health check
app.get('/', (req, res) => {
  res.send('Ok Driver + Company Backend Services are Running Successfully');
});


// ---------------- SOCKET.IO REALTIME CHAT ----------------

// Authentication for sockets
io.use(async (socket, next) => {
  try {
    const { token, role, vehicleId } = socket.handshake.auth || {};
    if (!token || !role) return next(new Error('unauthorized'));

    if (role === 'COMPANY') {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const company = await prisma.company.findUnique({ where: { id: decoded.id } });
      if (!company) return next(new Error('unauthorized'));
      socket.data.companyId = company.id;
    } else if (role === 'CLIENT') {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      socket.data.clientId = decoded.clientId;
    } else if (role === 'DRIVER') {
      socket.data.driver = true;
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
  const room = socket.data.vehicleId ? `vehicle:${socket.data.vehicleId}` : undefined;
  if (room) socket.join(room);

  console.log(`🔗 Socket connected: ${socket.id}, joined room: ${room}`);

  // Send chat message
  socket.on('chat:send', async (payload, cb) => {
    try {
      const { vehicleId, message } = payload || {};
      const vid = Number(vehicleId || socket.data.vehicleId);
      if (!vid || !message) return cb && cb({ ok: false, error: 'missing fields' });

      // Sender identify
      let data = { vehicleId: vid, message, senderType: 'CLIENT' };
      if (socket.data.companyId) {
        data.senderType = 'COMPANY';
        data.senderCompanyId = socket.data.companyId;
      } else if (socket.data.clientId) {
        data.senderType = 'CLIENT';
        data.senderClientId = socket.data.clientId;
      } else if (socket.data.driver) {
        data.senderType = 'DRIVER';
      }

      // Save chat in DB
      const chat = await prisma.chatMessage.create({ data });

      // Broadcast to room
      io.to(`vehicle:${vid}`).emit('chat:new', chat);

      cb && cb({ ok: true, chat });
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

      const chats = await prisma.chatMessage.findMany({
        where: { vehicleId: vid },
        orderBy: { createdAt: 'asc' }
      });

      cb && cb({ ok: true, chats });
    } catch (err) {
      console.error('chat:history error', err);
      cb && cb({ ok: false, error: 'internal' });
    }
  });

  socket.on('disconnect', () => {
    console.log(`❌ Socket disconnected: ${socket.id}`);
  });
});

// Start server
const PORT = process.env.PORT || 5000;
http.listen(PORT, () => {
  console.log(`✅ Server + Socket.IO started on port ${PORT}`);
});
