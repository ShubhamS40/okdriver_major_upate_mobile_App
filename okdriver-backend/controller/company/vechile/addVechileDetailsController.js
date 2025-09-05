const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Add a new vehicle
const addVehicle = async (req, res) => {
  try {
    const { vehicleNumber, password, model, type } = req.body;
    const companyId = req.company.id;

    // Validate required fields
    if (!vehicleNumber || !password) {
      return res.status(400).json({ message: "vehicleNumber and password are required" });
    }

    // Check if vehicle number already exists
    const existingVehicle = await prisma.vehicle.findUnique({
      where: { vehicleNumber },
    });

    if (existingVehicle) {
      return res.status(400).json({ message: "Vehicle with this number already exists" });
    }

    // 🚫 No hashing, save password as plain text
    const newVehicle = await prisma.vehicle.create({
      data: {
        vehicleNumber,
        password, // plain text
        model,
        type,
        company: {
          connect: { id: companyId },
        },
      },
    });

    return res.status(201).json({
      message: "Vehicle added successfully",
      vehicle: {
        id: newVehicle.id,
        vehicleNumber: newVehicle.vehicleNumber,
        model: newVehicle.model,
        type: newVehicle.type,
        companyId: newVehicle.companyId,
        status: newVehicle.status,
        createdAt: newVehicle.createdAt,
      },
    });
  } catch (error) {
    console.error("Error adding vehicle:", error);
    return res.status(500).json({ message: "Internal server error" });
  }
};

// Login vehicle by vehicleNumber and password
const loginVehicle = async (req, res) => {
  try {
    const { vehicleNumber, password } = req.body;

    if (!vehicleNumber || !password) {
      return res.status(400).json({ message: 'vehicleNumber and password are required' });
    }

    const vehicle = await prisma.vehicle.findUnique({ where: { vehicleNumber } });
    if (!vehicle) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    // 🚫 No bcrypt compare, plain text match
    if (password !== vehicle.password) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    return res.status(200).json({
      message: 'Login successful',
      vehicle: {
        id: vehicle.id,
        vehicleNumber: vehicle.vehicleNumber,
        model: vehicle.model,
        type: vehicle.type,
        companyId: vehicle.companyId,
        status: vehicle.status,
        createdAt: vehicle.createdAt,
      },
      token: null,
      sessionId: null,
    });
  } catch (error) {
    console.error('Error logging in vehicle:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
};

module.exports = { addVehicle, loginVehicle };
