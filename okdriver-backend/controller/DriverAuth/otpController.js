require('dotenv').config();
const twilio = require('twilio');
const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');

const client = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

const prisma = new PrismaClient();

// Generate a secure token
const generateToken = () => {
  return crypto.randomBytes(32).toString('hex');
};


// 📤 Send OTP
exports.sendOTP = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone || !phone.startsWith('+')) {
      return res.status(400).json({ error: "Phone number must include country code with '+' (e.g., +91XXXXXXXXXX)" });
    }

    const verification = await client.verify.v2
      .services(process.env.TWILIO_VERIFY_SERVICE_SID)
      .verifications.create({
        to: phone,
        channel: 'sms'
      });

    res.status(200).json({
      status: verification.status,
      message: 'OTP sent successfully',
    });
  } catch (error) {
    console.error("Send OTP error:", error);
    res.status(500).json({ error: error.message });
  }
};


exports.verifyOTP = async (req, res) => {
  const { phone, code, deviceInfo } = req.body;

  if (!phone || !phone.startsWith('+')) {
    return res.status(400).json({ error: "Phone number must include country code with '+' (e.g., +91XXXXXXXXXX)" });
  }

  try {
    // 1. Verify OTP with Twilio
    const verificationCheck = await client.verify
      .v2.services(process.env.TWILIO_VERIFY_SERVICE_SID)
      .verificationChecks.create({
        to: phone,
        code,
      });

    if (verificationCheck.status !== 'approved') {
      return res.status(400).json({ error: 'Invalid OTP' });
    }

    // 2. Check if user already exists
    const existingDriver = await prisma.driver.findUnique({
      where: { phone: phone },
    });

    let driver;
    let isNewUser = false;

    if (existingDriver) {
      // ✅ Existing user
      driver = existingDriver;
    } else {
      // 🆕 New user, save phone with blank values
      driver = await prisma.driver.create({
        data: {
          phone: phone,
          firstName: '',
          lastName: '',
          email: '',
          latitude: 0.0,
          longitude: 0.0,
        }
      });
      isNewUser = true;
    }

    // 3. Deactivate any existing sessions for this driver
    await prisma.driverSession.updateMany({
      where: {
        driverId: driver.id,
        isActive: true
      },
      data: {
        isActive: false
      }
    });

    // 4. Create new session
    const token = generateToken();
    const sessionExpiry = new Date();
    sessionExpiry.setDate(sessionExpiry.getDate() + 30); // 30 days expiry

    const session = await prisma.driverSession.create({
      data: {
        driverId: driver.id,
        token: token,
        deviceInfo: deviceInfo || 'Unknown Device',
        expiresAt: sessionExpiry
      }
    });

    return res.status(200).json({
      message: isNewUser ? 'OTP verified, new user registered' : 'OTP verified, user logged in',
      isNewUser: isNewUser,
      user: driver,
      token: token,
      sessionId: session.id
    });

  } catch (error) {
    console.error('Verify OTP error:', error);
    res.status(500).json({ error: 'Failed to verify OTP' });
  }
};
