require('dotenv').config();
const twilio = require('twilio');
const { PrismaClient } = require('@prisma/client');

const client = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

const prisma = new PrismaClient();


// controller/DriverAuth/otpController.js

exports.registerNewUser = async (req, res) => {
  const { id, firstName, lastName, email,  emergencyContact } = req.body;

  try {
    const updatedDriver = await prisma.driver.update({
      where: { id },
      data: {
        firstName,
        lastName,
        email,
        emergencyContact,
      },
    });

    res.status(200).json({
      message: 'User registration successful',
      user: updatedDriver,
    });

  } catch (error) {
    console.error("User registration failed:", error);
    res.status(500).json({ error: 'Failed to update user details' });
  }
};
