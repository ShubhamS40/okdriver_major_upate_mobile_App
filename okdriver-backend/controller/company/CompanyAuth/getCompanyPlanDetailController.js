const { PrismaClient } = require('@prisma/client');
const jwt = require('jsonwebtoken');

const prisma = new PrismaClient();

const getCompanyPlan = async (req, res) => {
  try {
    // Get token from Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ message: 'Authorization token required' });
    }

    const token = authHeader.split(' ')[1];
    
    // Verify JWT token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const companyId = decoded.id;

    // Verify company exists
    const company = await prisma.company.findUnique({
      where: { id: companyId }
    });

    if (!company) {
      return res.status(404).json({ message: 'Company not found' });
    }

    // Get all subscriptions purchased by the company (including expired ones)
    const allPurchasedSubscriptions = await prisma.companySubscription.findMany({
      where: {
        companyId: companyId
      },
      include: {
        plan: {
          include: {
            features: true,
            services: true
          }
        }
      },
      orderBy: [
        { status: 'asc' }, // ACTIVE first, then EXPIRED, then CANCELLED
        { createdAt: 'desc' } // Most recent first
      ]
    });

    // Separate subscriptions by status
    const activeSubscriptions = allPurchasedSubscriptions.filter(sub => sub.status === 'ACTIVE');
    const expiredSubscriptions = allPurchasedSubscriptions.filter(sub => sub.status === 'EXPIRED');
    const cancelledSubscriptions = allPurchasedSubscriptions.filter(sub => sub.status === 'CANCELLED');

    // Separate by plan type
    const subscriptionPlans = allPurchasedSubscriptions.filter(sub => sub.plan && sub.plan.planType === 'SUBSCRIPTION');
    const vehicleLimitPlans = allPurchasedSubscriptions.filter(sub => sub.plan && sub.plan.planType === 'VEHICLE_LIMIT');
    const clientLimitPlans = allPurchasedSubscriptions.filter(sub => sub.plan && sub.plan.planType === 'CLIENT_LIMIT');

    // Format the response data
    const formattedSubscriptions = allPurchasedSubscriptions.map(subscription => ({
      subscriptionId: subscription.id,
      subscriptionStatus: subscription.status,
      subscriptionStartDate: subscription.startAt,
      subscriptionEndDate: subscription.endAt,
      subscriptionCreatedAt: subscription.createdAt,
      paymentReference: subscription.paymentRef,
      
      // Plan details
      plan: {
        id: subscription.plan.id,
        name: subscription.plan.name,
        description: subscription.plan.description,
        price: subscription.plan.price,
        planType: subscription.plan.planType,
        durationDays: subscription.plan.durationDays,
        billingCycle: subscription.plan.billingCycle,
        vehicleLimit: subscription.plan.vehicleLimit,
        clientLimit: subscription.plan.clientLimit,
        storageLimitGB: subscription.plan.storageLimitGB,
        keyAdvantages: subscription.plan.keyAdvantages,
        isActive: subscription.plan.isActive,
        
        // Plan features
        features: subscription.plan.features.map(feature => ({
          id: feature.id,
          name: feature.name,
          description: feature.description,
          isActive: feature.isActive
        })),
        
        // Plan services
        services: subscription.plan.services.map(service => ({
          id: service.id,
          name: service.name,
          description: service.description,
          serviceType: service.serviceType,
          color: service.color,
          isActive: service.isActive
        }))
      },
      
      // Subscription duration and remaining days
      isCurrentlyActive: subscription.status === 'ACTIVE' && new Date() <= subscription.endAt,
      remainingDays: subscription.status === 'ACTIVE' ? 
        Math.max(0, Math.ceil((subscription.endAt - new Date()) / (1000 * 60 * 60 * 24))) : 0
    }));

    // Calculate summary statistics
    const totalSpent = allPurchasedSubscriptions.reduce((sum, sub) => {
      return sum + parseFloat(sub.plan.price || 0);
    }, 0);

    const currentActiveVehicleLimit = activeSubscriptions
      .filter(sub => sub.plan && sub.plan.planType === 'SUBSCRIPTION')
      .reduce((sum, sub) => sum + (sub.plan.vehicleLimit || 0), 0);

    const currentActiveClientLimit = activeSubscriptions
      .filter(sub => sub.plan && sub.plan.planType === 'SUBSCRIPTION')
      .reduce((sum, sub) => sum + (sub.plan.clientLimit || 0), 0);

    // Response object
    const response = {
      company: {
        id: company.id,
        name: company.name,
        email: company.email
      },
      
      summary: {
        totalPurchasedPlans: allPurchasedSubscriptions.length,
        totalActiveSubscriptions: activeSubscriptions.length,
        totalExpiredSubscriptions: expiredSubscriptions.length,
        totalCancelledSubscriptions: cancelledSubscriptions.length,
        totalAmountSpent: totalSpent,
        currentActiveVehicleLimit: currentActiveVehicleLimit,
        currentActiveClientLimit: currentActiveClientLimit
      },
      
      subscriptionsByType: {
        subscriptionPlans: {
          count: subscriptionPlans.length,
          active: subscriptionPlans.filter(sub => sub.status === 'ACTIVE').length,
          expired: subscriptionPlans.filter(sub => sub.status === 'EXPIRED').length,
          cancelled: subscriptionPlans.filter(sub => sub.status === 'CANCELLED').length
        },
        vehicleLimitPlans: {
          count: vehicleLimitPlans.length,
          active: vehicleLimitPlans.filter(sub => sub.status === 'ACTIVE').length,
          expired: vehicleLimitPlans.filter(sub => sub.status === 'EXPIRED').length,
          cancelled: vehicleLimitPlans.filter(sub => sub.status === 'CANCELLED').length
        },
        clientLimitPlans: {
          count: clientLimitPlans.length,
          active: clientLimitPlans.filter(sub => sub.status === 'ACTIVE').length,
          expired: clientLimitPlans.filter(sub => sub.status === 'EXPIRED').length,
          cancelled: clientLimitPlans.filter(sub => sub.status === 'CANCELLED').length
        }
      },
      
      subscriptionsByStatus: {
        active: activeSubscriptions.map(sub => formattedSubscriptions.find(fs => fs.subscriptionId === sub.id)),
        expired: expiredSubscriptions.map(sub => formattedSubscriptions.find(fs => fs.subscriptionId === sub.id)),
        cancelled: cancelledSubscriptions.map(sub => formattedSubscriptions.find(fs => fs.subscriptionId === sub.id))
      },
      
      allPurchasedPlans: formattedSubscriptions
    };

    res.json(response);

  } catch (error) {
    console.error('Error fetching company purchased plans:', error);
    res.status(500).json({ error: error.message });
  }
};

module.exports = { getCompanyPlan };