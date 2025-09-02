const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function testAssignment() {
  try {
    console.log('🧪 Testing assignment functionality...');
    
    // Get a company
    const company = await prisma.company.findFirst();
    if (!company) {
      console.log('❌ No company found');
      return;
    }
    console.log('✅ Found company:', company.id, company.name);
    
    // Get a vehicle for this company
    const vehicle = await prisma.vehicle.findFirst({
      where: { companyId: company.id }
    });
    if (!vehicle) {
      console.log('❌ No vehicle found for company');
      return;
    }
    console.log('✅ Found vehicle:', vehicle.id, vehicle.vehicleNumber);
    
    // Get or create a client list
    let list = await prisma.clientList.findFirst({
      where: { companyId: company.id }
    });
    if (!list) {
      list = await prisma.clientList.create({
        data: {
          name: 'Test List',
          companyId: company.id
        }
      });
      console.log('✅ Created test list:', list.id, list.name);
    } else {
      console.log('✅ Found existing list:', list.id, list.name);
    }
    
    // Get or create a client
    let client = await prisma.client.findFirst({
      where: { companyId: company.id }
    });
    if (!client) {
      client = await prisma.client.create({
        data: {
          email: 'test@example.com',
          name: 'Test Client',
          companyId: company.id
        }
      });
      console.log('✅ Created test client:', client.id, client.email);
    } else {
      console.log('✅ Found existing client:', client.id, client.email);
    }
    
    // Add client to list if not already there
    const existingMember = await prisma.clientListMember.findFirst({
      where: {
        clientListId: list.id,
        clientId: client.id
      }
    });
    
    if (!existingMember) {
      await prisma.clientListMember.create({
        data: {
          clientListId: list.id,
          clientId: client.id
        }
      });
      console.log('✅ Added client to list');
    } else {
      console.log('✅ Client already in list');
    }
    
    // Test assignment
    console.log('🔗 Testing assignment...');
    const access = await prisma.clientVehicleAccess.upsert({
      where: {
        clientId_vehicleId: {
          clientId: client.id,
          vehicleId: vehicle.id
        }
      },
      update: {},
      create: {
        companyId: company.id,
        clientId: client.id,
        vehicleId: vehicle.id
      }
    });
    
    console.log('✅ Assignment successful:', access);
    
    // Verify assignment
    const verification = await prisma.clientVehicleAccess.findFirst({
      where: {
        clientId: client.id,
        vehicleId: vehicle.id,
        companyId: company.id
      }
    });
    
    if (verification) {
      console.log('✅ Assignment verified successfully');
    } else {
      console.log('❌ Assignment verification failed');
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error);
  } finally {
    await prisma.$disconnect();
  }
}

testAssignment();
