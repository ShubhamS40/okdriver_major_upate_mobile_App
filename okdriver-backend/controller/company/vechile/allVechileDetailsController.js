const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Get all vehicles for a company
const getAllVehicles = async (req, res) => {
  try {
    const companyId = req.company.id;
    console.log('🚗 Fetching vehicles for company:', companyId);
    
    const vehicles = await prisma.vehicle.findMany({
      where: { companyId },
      select: {
        id: true,
        vehicleNumber: true,
        model: true,
        type: true,
        status: true,
        createdAt: true,
        updatedAt: true
      }
    });

    console.log('✅ Found vehicles:', vehicles.length, 'for company:', companyId);
    console.log('📋 Vehicle details:', vehicles);

    return res.status(200).json(vehicles);
  } catch (error) {
    console.error("❌ Error fetching vehicles:", error);
    return res.status(500).json({ message: "Internal server error" });
  }
};

module.exports = { getAllVehicles };
