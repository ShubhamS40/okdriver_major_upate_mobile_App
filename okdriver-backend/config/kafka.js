const { Kafka } = require('kafkajs');

// Kafka configuration
const kafka = new Kafka({
  clientId: 'okdriver-backend',
  brokers: process.env.KAFKA_BROKERS?.split(',') || ['localhost:9092'],
  retry: {
    initialRetryTime: 100,
    retries: 8
  }
});

// Create producer instance
const producer = kafka.producer({
  allowAutoTopicCreation: true,
  transactionTimeout: 30000
});

// Create consumer instance
const consumer = kafka.consumer({ 
  groupId: 'vehicle-location-processor',
  sessionTimeout: 30000,
  heartbeatInterval: 3000
});

// Topics
const TOPICS = {
  VEHICLE_LOCATION_UPDATE: 'vehicle-location-update',
  VEHICLE_LOCATION_PROCESSED: 'vehicle-location-processed'
};

// Initialize producer
async function initializeProducer() {
  try {
    await producer.connect();
    console.log('✅ Kafka producer connected successfully');
  } catch (error) {
    console.error('❌ Failed to connect Kafka producer:', error);
    throw error;
  }
}

// Initialize consumer
async function initializeConsumer() {
  try {
    await consumer.connect();
    await consumer.subscribe({ 
      topic: TOPICS.VEHICLE_LOCATION_UPDATE,
      fromBeginning: false 
    });
    console.log('✅ Kafka consumer connected and subscribed successfully');
  } catch (error) {
    console.error('❌ Failed to connect Kafka consumer:', error);
    throw error;
  }
}

// Send message to Kafka
async function sendMessage(topic, message) {
  try {
    await producer.send({
      topic,
      messages: [
        {
          key: message.vehicleNumber || 'unknown',
          value: JSON.stringify(message),
          timestamp: Date.now()
        }
      ]
    });
    console.log(`✅ Message sent to Kafka topic: ${topic}`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to send message to Kafka topic ${topic}:`, error);
    return false;
  }
}

// Disconnect producer
async function disconnectProducer() {
  try {
    await producer.disconnect();
    console.log('✅ Kafka producer disconnected');
  } catch (error) {
    console.error('❌ Error disconnecting Kafka producer:', error);
  }
}

// Disconnect consumer
async function disconnectConsumer() {
  try {
    await consumer.disconnect();
    console.log('✅ Kafka consumer disconnected');
  } catch (error) {
    console.error('❌ Error disconnecting Kafka consumer:', error);
  }
}

module.exports = {
  kafka,
  producer,
  consumer,
  TOPICS,
  initializeProducer,
  initializeConsumer,
  sendMessage,
  disconnectProducer,
  disconnectConsumer
};
