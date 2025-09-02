/**
 * Get vehicles assigned to this client
 */
const getAssignedVehicles = async (req, res) => {
  try {
    const clientId = req.user?.clientId; // set by auth middleware
    if (!clientId) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const accesses = await prisma.clientVehicleAccess.findMany({
      where: { clientId },
      include: {
        vehicle: {
          include: {
            locations: {
              take: 1,
              orderBy: { recordedAt: 'desc' }
            }
          }
        }
      }
    });

    return res.status(200).json(accesses.map(a => ({
      vehicleId: a.vehicle.id,
      vehicleNumber: a.vehicle.vehicleNumber,
      type: a.vehicle.type,
      status: a.vehicle.status,
      latestLocation: a.vehicle.locations[0] || null
    })));
  } catch (error) {
    console.error("Error fetching assigned vehicles:", error);
    return res.status(500).json({ message: "Internal Server Error" });
  }
};


module.exports = { getAssignedVehicles };