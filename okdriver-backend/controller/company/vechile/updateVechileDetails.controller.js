const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const bcrypt = require('bcrypt');

// Update vehicle details
const updateVehicle = async (req, res) => {
  try {
    const { id } = req.params;
    const { vehicleNumber, password, model, type, status } = req.body;
    const companyId = req.company.id;

    // Check if vehicle exists and belongs to the company
    const vehicle = await prisma.vehicle.findFirst({
      where: { 
        id: parseInt(id),
        companyId: companyId
      },
    });

    if (!vehicle) {
      return res.status(404).json({ message: "Vehicle not found or access denied" });
    }

    // Prepare update data
    const updateData = {};

    if (vehicleNumber) updateData.vehicleNumber = vehicleNumber;
    if (model) updateData.model = model;
    if (type) updateData.type = type;
    if (status) updateData.status = status;

    // If password is provided, hash it
    if (password) {
      updateData.password = await bcrypt.hash(password, 10);
    }

    // Update vehicle
    const updatedVehicle = await prisma.vehicle.update({
      where: { id: parseInt(id) },
      data: updateData,
    });

    return res.status(200).json({
      message: "Vehicle updated successfully",
      vehicle: {
        id: updatedVehicle.id,
        vehicleNumber: updatedVehicle.vehicleNumber,
        model: updatedVehicle.model,
        type: updatedVehicle.type,
        status: updatedVehicle.status,
        updatedAt: updatedVehicle.updatedAt,
      },
    });
  } catch (error) {
    console.error("Error updating vehicle:", error);
    return res.status(500).json({ message: "Internal server error" });
  }
};

module.exports = { updateVehicle };
