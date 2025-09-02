// controller/admin/Plan/getAllDriverPlansController.js

const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * @desc    Fetch all Driver Plans
 * @route   GET /api/plans/driver
 * @access  Public/Admin
 */
const getAllDriverPlans = async (req, res) => {
  try {
    const driverPlans = await prisma.driverPlan.findMany({
      include: {
        services: true // Fetch associated services for each plan
      },
      orderBy: {
        price: 'asc' // Optional: sort plans by price ascending
      }
    });

    return res.status(200).json({
      message: "Driver Plans fetched successfully",
      data: driverPlans
    });

  } catch (error) {
    console.error("Error fetching driver plans:", error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
};

module.exports = { getAllDriverPlans };
