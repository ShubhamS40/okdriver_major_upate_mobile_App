const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function assignUserApiPlan() {
  const userId = "44eb4fdb-baa7-446e-a2e0-651efd31300c"; // User ID
  const planId = 14; // API Plan ID (365 days)
  const now = new Date();

  // 🔹 Step 1: Fetch plan details
  const plan = await prisma.apiPlan.findUnique({
    where: { id: planId },
  });

  if (!plan) {
    throw new Error('❌ Plan not found in ApiPlan table.');
  }

  // 🔹 Step 2: Calculate start and end date (default 365 days)
  const startAt = now;
  const endAt = new Date(startAt);
  endAt.setDate(startAt.getDate() + (plan.daysValidity || 365));

  // 🔹 Step 3: Check if subscription already exists
  const existing = await prisma.userApiSubscription.findFirst({
    where: { userId },
  });

  let subscription;

  if (existing) {
    // Update existing subscription
    subscription = await prisma.userApiSubscription.update({
      where: { id: existing.id },
      data: {
        planId,
        startAt,
        endAt,
        status: 'ACTIVE',
        paymentStatus: 'SUCCESS',
        paymentRef: 'manual_assignment',
      },
    });
    console.log('🔄 Existing user API subscription updated successfully ✅');
  } else {
    // Create new subscription
    subscription = await prisma.userApiSubscription.create({
      data: {
        userId,
        planId,
        startAt,
        endAt,
        status: 'ACTIVE',
        paymentStatus: 'SUCCESS',
        paymentRef: 'manual_assignment',
      },
    });
    console.log('✅ New user API subscription created successfully ✅');
  }

  // 🔹 Step 4: Verify the assigned plan
  const check = await prisma.userApiSubscription.findFirst({
    where: { userId },
    include: { plan: true },
  });

  console.log('\n📋 Subscription Details:');
  console.log({
    userId: check.userId,
    planName: check.plan?.name || plan.name,
    durationDays:  365,
    status: check.status,
    validTill: check.endAt,
  });
}

assignUserApiPlan()
  .catch((err) => console.error('❌ Error:', err))
  .finally(() => prisma.$disconnect());
