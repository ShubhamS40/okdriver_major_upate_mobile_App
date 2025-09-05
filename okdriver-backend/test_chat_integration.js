/**
 * Test script for real-time chat integration
 * Run this after starting the backend server
 */

const io = require('socket.io-client');

// Test vehicle login
async function testVehicleLogin() {
  console.log('🚗 Testing vehicle login...');
  
  try {
    const response = await fetch('http://localhost:5000/api/driver/vehicle-login', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        vehicleNumber: 'MH12AB1234',
        password: 'testpassword123'
      })
    });
    
    const data = await response.json();
    
    if (data.success) {
      console.log('✅ Vehicle login successful');
      console.log('Token:', data.data.token.substring(0, 20) + '...');
      return data.data.token;
    } else {
      console.log('❌ Vehicle login failed:', data.message);
      return null;
    }
  } catch (error) {
    console.log('❌ Vehicle login error:', error.message);
    return null;
  }
}

// Test company login (you'll need to implement this)
async function testCompanyLogin() {
  console.log('🏢 Testing company login...');
  
  // This would need to be implemented based on your company auth
  // For now, we'll assume you have a company token
  return 'your-company-token-here';
}

// Test socket connection
function testSocketConnection(token, userType) {
  console.log(`🔌 Testing socket connection as ${userType}...`);
  
  const socket = io('http://localhost:5000', {
    auth: {
      token: token
    }
  });
  
  socket.on('connect', () => {
    console.log('✅ Socket connected successfully');
    
    if (userType === 'company') {
      // Test sending message to vehicle
      socket.emit('company:send_message_to_vehicle', {
        vehicleId: 1,
        message: 'Hello from company!'
      });
    } else if (userType === 'driver') {
      // Test sending message to company
      socket.emit('driver:send_message_to_company', {
        message: 'Hello from driver!'
      });
    }
  });
  
  socket.on('disconnect', () => {
    console.log('❌ Socket disconnected');
  });
  
  socket.on('new_message', (message) => {
    console.log('📨 Received message:', message);
  });
  
  socket.on('error', (error) => {
    console.log('❌ Socket error:', error);
  });
  
  return socket;
}

// Main test function
async function runTests() {
  console.log('🧪 Starting chat integration tests...\n');
  
  // Test vehicle login
  const vehicleToken = await testVehicleLogin();
  if (!vehicleToken) {
    console.log('❌ Cannot proceed without vehicle token');
    return;
  }
  
  // Test company login
  const companyToken = await testCompanyLogin();
  if (!companyToken) {
    console.log('❌ Cannot proceed without company token');
    return;
  }
  
  console.log('\n🔌 Testing socket connections...');
  
  // Test driver socket
  const driverSocket = testSocketConnection(vehicleToken, 'driver');
  
  // Test company socket
  const companySocket = testSocketConnection(companyToken, 'company');
  
  // Keep connections alive for testing
  setTimeout(() => {
    console.log('\n✅ Test completed. Check the messages above for results.');
    driverSocket.disconnect();
    companySocket.disconnect();
    process.exit(0);
  }, 10000);
}

// Run tests
runTests().catch(console.error);
