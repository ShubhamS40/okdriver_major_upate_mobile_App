const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
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

    // ✅ Hash password before saving
    const hashedPassword = await bcrypt.hash(password, 10);
    const newVehicle = await prisma.vehicle.create({
      data: {
        vehicleNumber,
        password: hashedPassword, // hashed password
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

    const vehicle = await prisma.vehicle.findUnique({ 
      where: { vehicleNumber },
      include: {
        company: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }
      }
    });
    
    if (!vehicle) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    // Check if vehicle is active
    if (vehicle.status !== 'ACTIVE') {
      return res.status(401).json({ message: 'Vehicle is not active' });
    }

    // ✅ Use bcrypt to compare hashed password
    const isPasswordValid = await bcrypt.compare(password, vehicle.password);
    if (!isPasswordValid) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    // ✅ Generate JWT token for vehicle authentication
    const token = jwt.sign(
      {
        id: vehicle.id,
        type: 'driver',
        vehicleId: vehicle.id,
        vehicleNumber: vehicle.vehicleNumber,
        companyId: vehicle.companyId,
        companyName: vehicle.company.name
      },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    // Update vehicle's last activity
    await prisma.vehicle.update({
      where: { id: vehicle.id },
      data: { updatedAt: new Date() }
    });

    return res.status(200).json({
      success: true,
      message: 'Vehicle login successful',
      data: {
        token,
        vehicle: {
          id: vehicle.id,
          vehicleNumber: vehicle.vehicleNumber,
          model: vehicle.model,
          type: vehicle.type,
          status: vehicle.status,
          createdAt: vehicle.createdAt,
        },
        company: {
          id: vehicle.company.id,
          name: vehicle.company.name,
          email: vehicle.company.email
        }
      }
    });
  } catch (error) {
    console.error('Error logging in vehicle:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
};

module.exports = { addVehicle, loginVehicle };
