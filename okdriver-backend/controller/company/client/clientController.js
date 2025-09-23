const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
require('dotenv').config();

// Email transporter (configure via env)
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT || 587),
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

/**
 * Client login with email (create account if doesn't exist)
 */
const clientLogin = async (req, res) => {
  try {
    const { email, companyId } = req.body;
    if (!email || !companyId) {
      return res.status(400).json({ message: "Email and companyId are required" });
    }

    let client = await prisma.client.findUnique({ where: { email } });

    // Create client if not exists (must belong to company)
    if (!client) {
      client = await prisma.client.create({
        data: { email, companyId }
      });
    }

    // Generate JWT for client
    const token = jwt.sign({ clientId: client.id, companyId }, process.env.JWT_SECRET, {
      expiresIn: '7d'
    });

    return res.status(200).json({ message: "Login successful", token, client });
  } catch (error) {
    console.error("Error in client login:", error);
    return res.status(500).json({ message: "Internal Server Error" });
  }
};

module.exports = { clientLogin };

/**
 * Send OTP to client email only if they have at least one vehicle access
 */
const sendClientOtp = async (req, res) => {
  try {
    const { email } = req.body;
    console.log('📩 sendClientOtp called for', email);
    if (!email) {
      return res.status(400).json({ message: 'Email is required' });
    }

    const client = await prisma.client.findUnique({ where: { email } });
    console.log('🔎 client lookup:', client?.id);
    if (!client) {
      return res.status(403).json({ message: 'Access denied: email not in client list' });
    }

    const accessCount = await prisma.clientVehicleAccess.count({ where: { clientId: client.id } });
    console.log('🔗 access count:', accessCount);
    if (accessCount === 0) {
      return res.status(403).json({ message: 'Access denied: no vehicles assigned' });
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    // Store OTP using OTP table (reuse phone field to store email identifier)
    await prisma.oTP.create({
      data: {
        phone: email,
        code,
        expiresAt,
      },
    });

    const fromEmail = process.env.FROM_EMAIL || process.env.SMTP_USER;
    if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
      try {
        await transporter.sendMail({
          from: fromEmail,
          to: email,
          subject: 'Your OkDriver verification code',
          text: `Your verification code is ${code}. It expires in 10 minutes.`,
          html: `<p>Your verification code is <b>${code}</b>. It expires in 10 minutes.</p>`,
        });
        console.log('✅ OTP email queued to', email);
      } catch (mailErr) {
        console.error('✉️ SMTP send failed:', mailErr?.message || mailErr);
        if (process.env.NODE_ENV !== 'production') {
          console.log('⚠️ Dev fallback: OTP for', email, 'is', code);
        } else {
          return res.status(500).json({ message: 'Failed to send OTP email' });
        }
      }
    } else {
      console.log('⚠️ SMTP not configured. Dev OTP for', email, 'is', code);
    }

    return res.status(200).json({ message: 'OTP sent successfully' });
  } catch (error) {
    console.error('sendClientOtp error:', error);
    return res.status(500).json({ message: 'Internal Server Error' });
  }
};

/**
 * Verify OTP for client email and ensure access exists
 */
const verifyClientOtp = async (req, res) => {
  try {
    const { email, code } = req.body;
    if (!email || !code) {
      return res.status(400).json({ message: 'Email and code are required' });
    }

    const client = await prisma.client.findUnique({ where: { email } });
    if (!client) {
      return res.status(403).json({ message: 'Access denied' });
    }

    const otp = await prisma.oTP.findFirst({
      where: { phone: email, code },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp) {
      return res.status(400).json({ message: 'Invalid code' });
    }
    if (otp.expiresAt < new Date()) {
      return res.status(400).json({ message: 'Code expired' });
    }

    const accessCount = await prisma.clientVehicleAccess.count({ where: { clientId: client.id } });
    if (accessCount === 0) {
      return res.status(403).json({ message: 'Access denied: no vehicles assigned' });
    }

    // Optional: clean up OTPs for this email
    await prisma.oTP.deleteMany({ where: { phone: email } });

    // Issue a token with client and company information
    const token = jwt.sign({ 
      clientId: client.id, 
      companyId: client.companyId 
    }, process.env.JWT_SECRET, { expiresIn: '7d' });

    return res.status(200).json({ 
      message: 'Verified', 
      token, 
      client: { 
        id: client.id, 
        email: client.email, 
        companyId: client.companyId 
      } 
    });
  } catch (error) {
    console.error('verifyClientOtp error:', error);
    return res.status(500).json({ message: 'Internal Server Error' });
  }
};

module.exports.sendClientOtp = sendClientOtp;
module.exports.verifyClientOtp = verifyClientOtp;