
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const prisma = new PrismaClient();


// Add Vehicle
export const addVehicle = async (req, res) => {
  try {
    const { vehicleNo, password } = req.body;
    const companyId = req.user.id; // from JWT middleware

    const hashedPassword = await bcrypt.hash(password, 10);

    const vehicle = await prisma.vehicle.create({
      data: {
        vehicleNo,
        password: hashedPassword,
        companyId
      }
    });

    res.status(201).json({ message: "Vehicle added", vehicle });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};