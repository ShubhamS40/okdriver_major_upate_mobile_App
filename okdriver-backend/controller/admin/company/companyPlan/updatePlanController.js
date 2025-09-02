// controller/admin/Plan/companyPlanUpdateController.js

const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * @desc    Update a company's selected plan
 * @route   PUT /api/plans/company/update
 * @access  Company (JWT required)
 */
const updateCompanyPlan = async (req, res) => {
  try {
    const companyId = req.user?.id; // Ensure verifyCompanyAuth middleware sets req.user.id
    const { planId } = req.body;

    // Validate company authentication
    if (!companyId) {
      return res.status(401).json({ message: "Unauthorized: Company ID missing" });
    }

    // Validate input
    if (!planId) {
      return res.status(400).json({ message: "Plan ID is required" });
    }

    // Check if plan exists in companyPlan table
    const plan = await prisma.companyPlan.findUnique({ where: { id: planId } });
    if (!plan) {
      return res.status(404).json({ message: "Plan not found" });
    }

    // Calculate plan start and end date
    const startDate = new Date();
    const endDate = new Date(startDate);
    endDate.setDate(startDate.getDate() + (plan.durationDays || 30)); // Use durationDays from companyPlan table

    // Update company's plan info
    const updatedCompany = await prisma.company.update({
      where: { id: companyId },
      data: {
        companyPlanId: planId,
        planStartDate: startDate,
        planEndDate: endDate
      },
      include: {
        companyPlan: true // Include updated plan details in response
      }
    });

    return res.status(200).json({
      message: "Company plan updated successfully",
      data: updatedCompany
    });

  } catch (error) {
    console.error("Error updating company plan:", error);

    // Handle Prisma known errors
    if (error.code === 'P2025') {
      return res.status(404).json({ message: "Company not found" });
    }

    return res.status(500).json({ message: "Internal Server Error" });
  }
};

module.exports = { updateCompanyPlan };
