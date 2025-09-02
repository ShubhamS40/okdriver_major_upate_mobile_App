const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Update an existing DriverPlan
 */
const updateDriverPlan = async (req, res) => {
  try {
    const { id } = req.params; // Plan ID from URL params
    const {
      name,
      description,
      price,
      billingCycle,
      durationDays,
      benefits,
      features,
      storageLimitGB,
      services // Array of service IDs
    } = req.body;

    // Check if DriverPlan exists
    const existingPlan = await prisma.driverPlan.findUnique({
      where: { id: parseInt(id) },
      include: { services: true }
    });

    if (!existingPlan) {
      return res.status(404).json({ error: "Driver Plan not found" });
    }

    // Update DriverPlan
    const updatedPlan = await prisma.driverPlan.update({
      where: { id: parseInt(id) },
      data: {
        name: name ?? existingPlan.name,
        description: description ?? existingPlan.description,
        price: price ?? existingPlan.price,
        billingCycle: billingCycle ?? existingPlan.billingCycle,
        durationDays: durationDays ?? existingPlan.durationDays,
        benefits: benefits ?? existingPlan.benefits,
        features: features ?? existingPlan.features,
        storageLimitGB: storageLimitGB ?? existingPlan.storageLimitGB,
        services: services
          ? {
              set: services.map(serviceId => ({ id: serviceId }))
            }
          : undefined
      },
      include: { services: true }
    });

    return res.status(200).json({ message: "Driver Plan updated successfully", data: updatedPlan });

  } catch (error) {
    console.error("Error updating driver plan:", error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
};

module.exports = { updateDriverPlan };
