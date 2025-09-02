const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Create a new CompanyPlan
 */
const createCompanyPlan = async (req, res) => {
  try {
    const {
      name,
      description,
      price,
      durationDays,
      billingCycle,
      keyAdvantages,
      vehicleLimit,
      storageLimitGB,
      features,  // Array of feature IDs to associate
      services   // Array of service IDs to associate
    } = req.body;

    // Basic validations
    if (!name || !price || !durationDays || !billingCycle || !vehicleLimit || !storageLimitGB) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    // Create the CompanyPlan
    const companyPlan = await prisma.companyPlan.create({
      data: {
        name,
        description,
        price,
        durationDays,
        billingCycle,
        keyAdvantages: keyAdvantages || [],
        vehicleLimit,
        storageLimitGB,
        features: features && features.length > 0
          ? { connect: features.map(id => ({ id })) }
          : undefined,
        services: services && services.length > 0
          ? { connect: services.map(id => ({ id })) }
          : undefined
      },
      include: {
        features: true,
        services: true
      }
    });

    return res.status(201).json({ message: "Company Plan created successfully", data: companyPlan });

  } catch (error) {
    console.error("Error creating company plan:", error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
};

module.exports = { createCompanyPlan };
