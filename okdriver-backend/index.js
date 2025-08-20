const express = require('express');
const dotenv = require('dotenv');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

// Driver routes
const otpRoutes = require('./routes/DriverAuth/otpRoutes');
const driverRegistration = require('./routes/DriverAuth/driverRegistration');
const driverAuthRoutes = require('./routes/DriverAuth/driverAuth');

// Company routes
const companyRoutes = require('./routes/CompanyAuthRoutes/companyAuthRoute');

// Admin routes
const adminPlanRoutes =require('./routes/admin/plan/planRoute')

dotenv.config();
const app = express();

// Middlewares
app.use(cors());
app.use(express.json());

// Static audio serving and directory setup (for Voice Assistant)
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

// Admin routes
app.use('/api/admin/plan', adminPlanRoutes);

app.use('/api/admin/auth', require('./routes/admin/adminAuth/adminAuthRoute'));

// Voice Assistant routes
app.use('/api/assistant', require('./routes/DriverVoiceAssistant/driverVoiceAssistant'));

// Health check route
app.get('/', (req, res) => {
  res.send('Ok Driver + Company Backend Services are Running Successfully');
});

// Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`✅ Server started on port ${PORT}`);
});
