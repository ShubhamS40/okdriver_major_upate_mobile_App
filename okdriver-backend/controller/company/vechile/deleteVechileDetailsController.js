const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Delete a vehicle
const deleteVehicle = async (req, res) => {
  try {
    const { id } = req.params;
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

    // Delete vehicle
    await prisma.vehicle.delete({
      where: { id: parseInt(id) },
    });

    return res.status(200).json({ message: "Vehicle deleted successfully" });
  } catch (error) {
    console.error("Error deleting vehicle:", error);
    return res.status(500).json({ message: "Internal server error" });
  }
};

module.exports = { deleteVehicle };
