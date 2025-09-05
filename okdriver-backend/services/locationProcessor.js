const { PrismaClient } = require('@prisma/client');
const { consumer, TOPICS } = require('../config/kafka');
const webSocketService = require('./websocketService');

const prisma = new PrismaClient();

class LocationProcessor {
  constructor() {
    this.locationBuffer = new Map(); // Buffer for batching location updates
    this.batchSize = 50; // Process in batches of 50
    this.batchTimeout = 5000; // Process batch every 5 seconds
    this.batchTimer = null;
    this.isProcessing = false;
  }

  // Start processing location updates from Kafka
  async start() {
    try {
      console.log('🚀 Starting location processor...');
      
      // Start batch processing timer
      this.startBatchTimer();
      
      // Start consuming messages
      await consumer.run({
        eachMessage: async ({ topic, partition, message }) => {
          try {
            await this.processLocationMessage(message);
          } catch (error) {
            console.error('❌ Error processing location message:', error);
          }
        }
      });
      
      console.log('✅ Location processor started successfully');
    } catch (error) {
      console.error('❌ Failed to start location processor:', error);
      throw error;
    }
  }

  // Process individual location message from Kafka
  async processLocationMessage(message) {
    try {
      const locationData = JSON.parse(message.value.toString());
      const vehicleNumber = message.key.toString();
      
      console.log(`📍 Processing location update for vehicle: ${vehicleNumber}`);
      
      // Add to buffer for batch processing
      this.addToBuffer(vehicleNumber, locationData);
      
      // Broadcast real-time update via WebSocket
      this.broadcastRealTimeUpdate(vehicleNumber, locationData);
      
    } catch (error) {
      console.error('❌ Error processing location message:', error);
    }
  }

  // Add location data to buffer for batch processing
  addToBuffer(vehicleNumber, locationData) {
    if (!this.locationBuffer.has(vehicleNumber)) {
      this.locationBuffer.set(vehicleNumber, []);
    }
    
    // Add timestamp if not present
    if (!locationData.timestamp) {
      locationData.timestamp = new Date();
    }
    
    this.locationBuffer.get(vehicleNumber).push(locationData);
    
    // Check if buffer is full for this vehicle
    if (this.locationBuffer.get(vehicleNumber).length >= this.batchSize) {
      this.processBatchForVehicle(vehicleNumber);
    }
  }

  // Start batch processing timer
  startBatchTimer() {
    this.batchTimer = setInterval(() => {
      this.processAllBatches();
    }, this.batchTimeout);
  }

  // Process all pending batches
  async processAllBatches() {
    if (this.isProcessing || this.locationBuffer.size === 0) {
      return;
    }

    this.isProcessing = true;
    
    try {
      const vehicleNumbers = Array.from(this.locationBuffer.keys());
      console.log(`🔄 Processing ${vehicleNumbers.length} vehicle batches...`);
      
      for (const vehicleNumber of vehicleNumbers) {
        await this.processBatchForVehicle(vehicleNumber);
      }
      
      console.log('✅ All batches processed successfully');
    } catch (error) {
      console.error('❌ Error processing batches:', error);
    } finally {
      this.isProcessing = false;
    }
  }

  // Process batch for a specific vehicle
  async processBatchForVehicle(vehicleNumber) {
    const locations = this.locationBuffer.get(vehicleNumber);
    if (!locations || locations.length === 0) {
      return;
    }

    try {
      console.log(`🔄 Processing batch of ${locations.length} locations for vehicle ${vehicleNumber}`);
      
      // Get vehicle ID
      const vehicle = await prisma.vehicle.findUnique({
        where: { vehicleNumber }
      });

      if (!vehicle) {
        console.log(`⚠️ Vehicle not found: ${vehicleNumber}, skipping batch`);
        this.locationBuffer.delete(vehicleNumber);
        return;
      }

      // Prepare batch data for database insertion
      const batchData = locations.map(location => ({
        vehicleId: vehicle.id,
        lat: parseFloat(location.latitude),
        lng: parseFloat(location.longitude),
        speedKph: location.speedKph ? parseFloat(location.speedKph) : null,
        headingDeg: location.headingDeg ? parseInt(location.headingDeg) : null,
        recordedAt: new Date(location.timestamp)
      }));

      // Use Prisma transaction for batch insert
      await prisma.$transaction(async (tx) => {
        // Insert all locations in batch
        await tx.vehicleLocation.createMany({
          data: batchData,
          skipDuplicates: true // Skip duplicates if any
        });

        // Update vehicle's last known location (optional)
        const latestLocation = batchData[batchData.length - 1];
        await tx.vehicle.update({
          where: { id: vehicle.id },
          data: {
            lastLat: latestLocation.lat,
            lastLng: latestLocation.lng,
            lastLocationAt: latestLocation.recordedAt
          }
        });
      });

      console.log(`✅ Batch processed for vehicle ${vehicleNumber}: ${batchData.length} locations saved`);
      
      // Clear buffer for this vehicle
      this.locationBuffer.delete(vehicleNumber);
      
    } catch (error) {
      console.error(`❌ Error processing batch for vehicle ${vehicleNumber}:`, error);
      
      // Keep locations in buffer for retry, but limit size to prevent memory issues
      if (locations.length > this.batchSize * 2) {
        this.locationBuffer.set(vehicleNumber, locations.slice(-this.batchSize));
        console.log(`⚠️ Reduced buffer size for vehicle ${vehicleNumber} to prevent memory issues`);
      }
    }
  }

  // Broadcast real-time update via WebSocket
  broadcastRealTimeUpdate(vehicleNumber, locationData) {
    try {
      const realTimeData = {
        lat: parseFloat(locationData.latitude),
        lng: parseFloat(locationData.longitude),
        speedKph: locationData.speedKph || null,
        headingDeg: locationData.headingDeg || null,
        timestamp: locationData.timestamp || new Date()
      };
      
      webSocketService.broadcastLocationUpdate(vehicleNumber, realTimeData);
    } catch (error) {
      console.error(`❌ Error broadcasting real-time update for vehicle ${vehicleNumber}:`, error);
    }
  }

  // Get processing statistics
  getStats() {
    return {
      bufferSize: this.locationBuffer.size,
      totalBufferedLocations: Array.from(this.locationBuffer.values())
        .reduce((total, locations) => total + locations.length, 0),
      isProcessing: this.isProcessing,
      batchSize: this.batchSize,
      batchTimeout: this.batchTimeout
    };
  }

  // Stop the processor
  async stop() {
    try {
      console.log('🛑 Stopping location processor...');
      
      // Clear batch timer
      if (this.batchTimer) {
        clearInterval(this.batchTimer);
        this.batchTimer = null;
      }
      
      // Process any remaining batches
      if (this.locationBuffer.size > 0) {
        console.log(`🔄 Processing ${this.locationBuffer.size} remaining batches...`);
        await this.processAllBatches();
      }
      
      console.log('✅ Location processor stopped successfully');
    } catch (error) {
      console.error('❌ Error stopping location processor:', error);
    }
  }

  // Clean up resources
  async cleanup() {
    await this.stop();
    await prisma.$disconnect();
  }
}

// Create singleton instance
const locationProcessor = new LocationProcessor();

module.exports = locationProcessor;
