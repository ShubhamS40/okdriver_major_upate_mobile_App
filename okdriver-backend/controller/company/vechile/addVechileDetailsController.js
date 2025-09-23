const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

// Initialize Prisma Client with better error handling
const prisma = new PrismaClient({
  log: ['error', 'warn'],
  errorFormat: 'pretty',
});

// Test database connection on startup
async function initializeDatabase() {
  try {
    await prisma.$connect();
    console.log('✅ Database connected successfully');
    
    // Test a simple query to verify connection works
    await prisma.company.findFirst();
    console.log('✅ Database query test successful');
  } catch (error) {
    console.error('❌ Database connection failed:', error);
    process.exit(1);
  }
}

// Initialize on module load
initializeDatabase();

// Add a new vehicle
const addVehicle = async (req, res) => {
  try {
    const { vehicleNumber, password, model, type } = req.body;
    const companyId = req.company.id;

    console.log('=== ADD VEHICLE REQUEST ===');
    console.log('Request data:', { vehicleNumber, model, type, companyId });

    // Validate required fields
    if (!vehicleNumber || !password) {
      return res.status(400).json({ message: "vehicleNumber and password are required" });
    }

    // Check if Prisma client is available
    if (!prisma) {
      console.error('Prisma client not initialized');
      return res.status(500).json({ message: "Database connection error" });
    }

    // Check if vehicle number already exists
    const existingVehicle = await prisma.vehicle.findUnique({
      where: { vehicleNumber },
    });

    if (existingVehicle) {
      return res.status(400).json({ message: "Vehicle with this number already exists" });
    }
    
    console.log('=== FETCHING COMPANY SUBSCRIPTIONS ===');
    
    // Get all company subscriptions
    const allSubscriptions = await prisma.companySubscription.findMany({
      where: { companyId },
      include: { plan: true },
      orderBy: { createdAt: 'desc' }
    });

    console.log(`Found ${allSubscriptions.length} total subscriptions for company ${companyId}`);
    
    // Log all subscriptions with detailed info
    allSubscriptions.forEach((sub, index) => {
      const endDate = new Date(sub.endAt);
      const now = new Date();
      const isExpired = endDate <= now;
      
      console.log(`\n--- Subscription ${index + 1} ---`);
      console.log(`Plan Name: ${sub.plan.name}`);
      console.log(`Plan Type: ${sub.plan.planType}`);
      console.log(`Status: ${sub.status}`);
      console.log(`Vehicle Limit: ${sub.plan.vehicleLimit}`);
      console.log(`Start Date: ${sub.startAt}`);
      console.log(`End Date: ${sub.endAt}`);
      console.log(`End Date (parsed): ${endDate.toISOString()}`);
      console.log(`Current Time: ${now.toISOString()}`);
      console.log(`Is Expired: ${isExpired}`);
      console.log(`Days Remaining: ${Math.ceil((endDate - now) / (1000 * 60 * 60 * 24))}`);
      console.log(`--- End Subscription ${index + 1} ---\n`);
    });

    // Filter for subscriptions with ACTIVE status (same logic as getCompanyPlan API)
    const activeSubscriptions = allSubscriptions.filter(s => {
      const isActive = s.status === 'ACTIVE';
      
      console.log(`Checking subscription "${s.plan.name}":`, {
        status: s.status,
        isActive,
        willBeIncluded: isActive
      });
      
      return isActive;
    });

    console.log(`=== ACTIVE SUBSCRIPTIONS: ${activeSubscriptions.length} ===`);

    // Separate base plans and top-up plans with detailed logging
    const basePlans = activeSubscriptions.filter(s => s.plan.planType === 'SUBSCRIPTION');
    const topUpPlans = activeSubscriptions.filter(s => s.plan.planType === 'VEHICLE_LIMIT');

    console.log(`Base plans (SUBSCRIPTION): ${basePlans.length}`);
    basePlans.forEach(plan => {
      console.log(`  - ${plan.plan.name}: ${plan.plan.vehicleLimit} vehicles`);
    });
    
    console.log(`Top-up plans (VEHICLE_LIMIT): ${topUpPlans.length}`);
    topUpPlans.forEach(plan => {
      console.log(`  - ${plan.plan.name}: ${plan.plan.vehicleLimit} vehicles`);
    });
    
    // Must have at least one active base plan
    if (basePlans.length === 0) {
      console.log('❌ No active base plan found');
      return res.status(400).json({ 
        message: `No active subscription plan found. Please subscribe to a plan to add vehicles.` 
      });
    }
    
    // Calculate vehicle limits
    const baseVehicleLimit = basePlans.reduce((sum, subscription) => {
      const limit = subscription.plan.vehicleLimit || 0;
      console.log(`Adding base plan "${subscription.plan.name}": ${limit} vehicles`);
      return sum + limit;
    }, 0);
    
    const topUpVehicleLimit = topUpPlans.reduce((sum, subscription) => {
      const limit = subscription.plan.vehicleLimit || 0;
      console.log(`Adding top-up plan "${subscription.plan.name}": ${limit} vehicles`);
      return sum + limit;
    }, 0);
    
    const totalVehicleLimit = baseVehicleLimit + topUpVehicleLimit;
    
    console.log('=== VEHICLE LIMIT CALCULATION ===');
    console.log(`Base vehicle limit: ${baseVehicleLimit}`);
    console.log(`Top-up vehicle limit: ${topUpVehicleLimit}`);
    console.log(`Total vehicle limit: ${totalVehicleLimit}`);
    
    // Count existing vehicles
    const currentVehicleCount = await prisma.vehicle.count({
      where: { companyId }
    });
    
    console.log(`Current vehicle count: ${currentVehicleCount}`);
    console.log(`Attempting to add 1 vehicle, new total would be: ${currentVehicleCount + 1}`);
    
    // Check vehicle limit
    if (totalVehicleLimit > 0 && currentVehicleCount >= totalVehicleLimit) {
      console.log('❌ Vehicle limit exceeded');
      return res.status(400).json({ 
        message: `Vehicle limit reached. Your current plan allows a maximum of ${totalVehicleLimit} vehicles (Base: ${baseVehicleLimit} + Top-up: ${topUpVehicleLimit}). You currently have ${currentVehicleCount} vehicles. Please upgrade your plan to add more vehicles.`,
        vehicleLimitInfo: {
          currentVehicles: currentVehicleCount,
          totalLimit: totalVehicleLimit,
          baseLimit: baseVehicleLimit,
          topUpLimit: topUpVehicleLimit,
          canAdd: false
        }
      });
    }

    console.log('✅ Vehicle limit check passed, creating vehicle...');

    // Hash password before saving
    const hashedPassword = await bcrypt.hash(password, 10);
    
    // Create the new vehicle
    const newVehicle = await prisma.vehicle.create({
      data: {
        vehicleNumber,
        password: hashedPassword,
        model: model || null,
        type: type || null,
        company: {
          connect: { id: companyId },
        },
        status: 'ACTIVE',
      },
    });

    console.log('✅ Vehicle created successfully:', {
      id: newVehicle.id,
      vehicleNumber: newVehicle.vehicleNumber,
      companyId: newVehicle.companyId
    });

    const newVehicleCount = currentVehicleCount + 1;
    
    return res.status(201).json({
      message: "Vehicle added successfully",
      vehicle: {
        id: newVehicle.id,
        vehicleNumber: newVehicle.vehicleNumber,
        model: newVehicle.model,
        type: newVehicle.type,
        companyId: newVehicle.companyId,
        status: newVehicle.status,
        createdAt: newVehicle.createdAt,
      },
      vehicleLimitInfo: {
        currentVehicles: newVehicleCount,
        totalLimit: totalVehicleLimit,
        baseLimit: baseVehicleLimit,
        topUpLimit: topUpVehicleLimit,
        remainingSlots: totalVehicleLimit > 0 ? totalVehicleLimit - newVehicleCount : 'Unlimited'
      }
    });
    
  } catch (error) {
    console.error("❌ Error adding vehicle:", error);
    
    // More detailed error logging
    if (error.code === 'P2002') {
      return res.status(400).json({ message: "Vehicle number already exists" });
    } else if (error.code === 'P2025') {
      return res.status(400).json({ message: "Company not found" });
    } else if (error.message.includes('connect ECONNREFUSED')) {
      return res.status(500).json({ message: "Database connection failed" });
    }
    
    return res.status(500).json({ 
      message: "Internal server error",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

// Login vehicle by vehicleNumber and password
const loginVehicle = async (req, res) => {
  try {
    const { vehicleNumber, password } = req.body;

    if (!vehicleNumber || !password) {
      return res.status(400).json({ message: 'vehicleNumber and password are required' });
    }

    // Check if Prisma client is available
    if (!prisma) {
      console.error('Prisma client not initialized');
      return res.status(500).json({ message: "Database connection error" });
    }

    const vehicle = await prisma.vehicle.findUnique({ 
      where: { vehicleNumber },
      include: {
        company: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }
      }
    });
    
    if (!vehicle) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    // Check if vehicle is active
    if (vehicle.status !== 'ACTIVE') {
      return res.status(401).json({ message: 'Vehicle is not active' });
    }

    // Use bcrypt to compare hashed password
    const isPasswordValid = await bcrypt.compare(password, vehicle.password);
    if (!isPasswordValid) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    // Generate JWT token for vehicle authentication
    const token = jwt.sign(
      {
        id: vehicle.id,
        type: 'driver',
        vehicleId: vehicle.id,
        vehicleNumber: vehicle.vehicleNumber,
        companyId: vehicle.companyId,
        companyName: vehicle.company.name
      },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    // Update vehicle's last activity
    await prisma.vehicle.update({
      where: { id: vehicle.id },
      data: { updatedAt: new Date() }
    });

    return res.status(200).json({
      success: true,
      message: 'Vehicle login successful',
      data: {
        token,
        vehicle: {
          id: vehicle.id,
          vehicleNumber: vehicle.vehicleNumber,
          model: vehicle.model,
          type: vehicle.type,
          status: vehicle.status,
          createdAt: vehicle.createdAt,
        },
        company: {
          id: vehicle.company.id,
          name: vehicle.company.name,
          email: vehicle.company.email
        }
      }
    });
  } catch (error) {
    console.error('Error logging in vehicle:', error);
    return res.status(500).json({ 
      message: 'Internal server error',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

// Graceful shutdown
process.on('beforeExit', async () => {
  if (prisma) {
    await prisma.$disconnect();
    console.log('Database disconnected');
  }
});

module.exports = { addVehicle, loginVehicle };