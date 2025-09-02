const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const bcrypt = require('bcrypt');

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

    // Hash password before storing
    const hashedPassword = await bcrypt.hash(password, 10);
    
    // Create vehicle
    const newVehicle = await prisma.vehicle.create({
      data: {
        vehicleNumber,
        password: hashedPassword,
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

module.exports = { addVehicle };
