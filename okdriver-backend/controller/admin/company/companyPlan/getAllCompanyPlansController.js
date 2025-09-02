// controller/admin/Plan/companyPlanFetchController.js

const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * @desc    Fetch all company plans
 * @route   GET /api/plans/company
 * @access  Public/Admin
 */
const getAllCompanyPlans = async (req, res) => {
    try {
        const plans = await prisma.companyPlan.findMany({
            include: {
                features: true,
                services: true
            },
            orderBy: {
                price: 'asc' // Optional: Sort by price ascending
            }
        });

        return res.status(200).json({
            message: "Company plans fetched successfully",
            data: plans
        });

    } catch (error) {
        console.error("Error fetching company plans:", error);
        return res.status(500).json({ message: "Internal Server Error" });
    }
};

module.exports = { getAllCompanyPlans };
