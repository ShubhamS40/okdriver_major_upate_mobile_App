// Test script to verify message flow between company and driver
const { PrismaClient } = require('@prisma/client');
const jwt = require('jsonwebtoken');

const prisma = new PrismaClient();

async function testMessageFlow() {
  console.log('🧪 Testing Message Flow...\n');

  try {
    // Get a company and vehicle for testing
    const company = await prisma.company.findFirst();
    if (!company) {
      console.log('❌ No company found');
      return;
    }

    const vehicle = await prisma.vehicle.findFirst({
      where: { companyId: company.id }
    });
    if (!vehicle) {
      console.log('❌ No vehicle found for company');
      return;
    }

    console.log(`✅ Company: ${company.name} (ID: ${company.id})`);
    console.log(`✅ Vehicle: ${vehicle.vehicleNumber} (ID: ${vehicle.id})`);

    // Test 1: Create a test message from driver to company
    console.log('\n1. Testing driver message creation...');
    const driverMessage = await prisma.vehicleChat.create({
      data: {
        vehicleId: vehicle.id,
        companyId: company.id,
        senderType: 'DRIVER',
        message: 'Test message from driver',
        isRead: false
      }
    });
    console.log(`✅ Driver message created: ${driverMessage.message} (ID: ${driverMessage.id})`);

    // Test 2: Create a test message from company to driver
    console.log('\n2. Testing company message creation...');
    const companyMessage = await prisma.vehicleChat.create({
      data: {
        vehicleId: vehicle.id,
        companyId: company.id,
        senderType: 'COMPANY',
        message: 'Test message from company',
        isRead: false
      }
    });
    console.log(`✅ Company message created: ${companyMessage.message} (ID: ${companyMessage.id})`);

    // Test 3: Query messages for company
    console.log('\n3. Testing company message query...');
    const companyMessages = await prisma.vehicleChat.findMany({
      where: {
        vehicleId: vehicle.id,
        companyId: company.id
      },
      orderBy: { createdAt: 'asc' }
    });
    console.log(`✅ Found ${companyMessages.length} messages for company`);
    companyMessages.forEach(msg => {
      console.log(`   - ${msg.senderType}: ${msg.message} (${msg.createdAt})`);
    });

    // Test 4: Test JWT tokens
    console.log('\n4. Testing JWT tokens...');
    
    // Company token
    const companyToken = jwt.sign(
      {
        id: company.id,
        type: 'company',
        companyId: company.id,
        companyName: company.name
      },
      process.env.JWT_SECRET || 'test_secret',
      { expiresIn: '24h' }
    );
    console.log(`✅ Company token generated`);

    // Driver token
    const driverToken = jwt.sign(
      {
        id: vehicle.id,
        type: 'driver',
        vehicleId: vehicle.id,
        vehicleNumber: vehicle.vehicleNumber,
        companyId: vehicle.companyId,
        companyName: company.name
      },
      process.env.JWT_SECRET || 'test_secret',
      { expiresIn: '24h' }
    );
    console.log(`✅ Driver token generated`);

    // Test 5: Test socket room names
    console.log('\n5. Testing socket room names...');
    const vehicleRoom = `vehicle:${vehicle.id}`;
    const companyRoom = `company:${company.id}`;
    console.log(`✅ Vehicle room: ${vehicleRoom}`);
    console.log(`✅ Company room: ${companyRoom}`);

    // Test 6: Test message broadcasting data
    console.log('\n6. Testing message broadcasting data...');
    const messageData = {
      id: driverMessage.id,
      message: driverMessage.message,
      senderType: driverMessage.senderType,
      createdAt: driverMessage.createdAt,
      attachmentUrl: driverMessage.attachmentUrl,
      isRead: driverMessage.isRead,
      vehicleId: driverMessage.vehicleId,
      companyId: driverMessage.companyId
    };
    console.log(`✅ Message data for broadcasting:`, messageData);

    console.log('\n🎉 Message flow test completed successfully!');
    console.log('\n📋 Expected behavior:');
    console.log('   ✅ Driver sends message → Saved to database');
    console.log('   ✅ Message broadcasted to vehicle room (driver receives)');
    console.log('   ✅ Message broadcasted to company room (company receives)');
    console.log('   ✅ No message echoing or duplication');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
    console.error('Stack trace:', error.stack);
  } finally {
    await prisma.$disconnect();
  }
}

// Run the test
testMessageFlow();
