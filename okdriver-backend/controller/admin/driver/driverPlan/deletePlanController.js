const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Delete a DriverPlan by ID
 */
const deleteDriverPlan = async (req, res) => {
  try {
    const { id } = req.params;

    // Check if plan exists
    const existingPlan = await prisma.driverPlan.findUnique({
      where: { id: parseInt(id) },
    });

    if (!existingPlan) {
      return res.status(404).json({ error: "Driver Plan not found" });
    }

    // Delete the plan
    await prisma.driverPlan.delete({
      where: { id: parseInt(id) },
    });

    return res.status(200).json({ message: "Driver Plan deleted successfully" });

  } catch (error) {
    console.error("Error deleting driver plan:", error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
};

module.exports = { deleteDriverPlan };
