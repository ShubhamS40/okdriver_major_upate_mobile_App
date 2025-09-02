// controller/admin/Plan/companyPlanDeleteController.js

const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Delete a CompanyPlan by ID
 */
const deleteCompanyPlan = async (req, res) => {
  try {
    const { id } = req.params;

    // Check if ID is provided and is a number
    if (!id || isNaN(id)) {
      return res.status(400).json({ error: "Invalid CompanyPlan ID" });
    }

    // Check if CompanyPlan exists
    const existingPlan = await prisma.companyPlan.findUnique({
      where: { id: parseInt(id) },
      include: { features: true, services: true }
    });

    if (!existingPlan) {
      return res.status(404).json({ error: "Company Plan not found" });
    }

    // Check if this plan is assigned as current plan to any company
    const activeCompanies = await prisma.company.findMany({
      where: { currentPlanId: parseInt(id) },
      select: { id: true, name: true }
    });

    // Also check if there are subscriptions referencing this plan
    const subscriptionCount = await prisma.companySubscription.count({
      where: { planId: parseInt(id) }
    });

    if (activeCompanies.length > 0 || subscriptionCount > 0) {
      return res.status(400).json({
        error: "Cannot delete this plan because it is in use by companies or subscriptions",
        companies: activeCompanies,
        subscriptions: subscriptionCount
      });
    }

    // Delete CompanyPlan
    await prisma.companyPlan.delete({ where: { id: parseInt(id) } });

    return res.status(200).json({ message: "Company Plan deleted successfully" });

  } catch (error) {
    console.error("Error deleting company plan:", error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
};

module.exports = { deleteCompanyPlan };
