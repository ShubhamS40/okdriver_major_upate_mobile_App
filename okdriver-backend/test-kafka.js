const { sendMessage, TOPICS, initializeProducer, disconnectProducer } = require('./config/kafka');

async function testKafkaConnection() {
  try {
    console.log('🧪 Testing Kafka connection...');
    
    // Initialize producer
    await initializeProducer();
    
    // Test message
    const testLocation = {
      vehicleNumber: 'TEST001',
      latitude: 19.0760,
      longitude: 72.8777,
      speedKph: 45.5,
      headingDeg: 180,
      timestamp: new Date().toISOString(),
      vehicleId: 1,
      companyId: 1
    };
    
    console.log('📤 Sending test location to Kafka...');
    const success = await sendMessage(TOPICS.VEHICLE_LOCATION_UPDATE, testLocation);
    
    if (success) {
      console.log('✅ Test message sent successfully to Kafka');
      console.log('📍 Test location data:', testLocation);
    } else {
      console.log('❌ Failed to send test message to Kafka');
    }
    
  } catch (error) {
    console.error('❌ Error testing Kafka:', error);
  } finally {
    // Cleanup
    await disconnectProducer();
    console.log('🧹 Cleanup completed');
  }
}

// Run test if this file is executed directly
if (require.main === module) {
  testKafkaConnection()
    .then(() => {
      console.log('🏁 Test completed');
      process.exit(0);
    })
    .catch((error) => {
      console.error('💥 Test failed:', error);
      process.exit(1);
    });
}

module.exports = { testKafkaConnection };
