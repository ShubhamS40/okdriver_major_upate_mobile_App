const WebSocket = require('ws');
const { TOPICS } = require('../config/kafka');

class WebSocketService {
  constructor() {
    this.wss = null;
    this.clients = new Map(); // Map to store connected clients
    this.vehicleSubscriptions = new Map(); // Map to store vehicle subscriptions
  }

  // Initialize WebSocket server
  initialize(server) {
    this.wss = new WebSocket.Server({ server });
    
    this.wss.on('connection', (ws, req) => {
      console.log('🔌 New WebSocket connection established');
      
      // Handle client connection
      this.handleConnection(ws, req);
      
      // Handle client disconnection
      ws.on('close', () => {
        this.handleDisconnection(ws);
      });
      
      // Handle incoming messages
      ws.on('message', (message) => {
        this.handleMessage(ws, message);
      });
    });
    
    console.log('✅ WebSocket server initialized');
  }

  // Handle new client connection
  handleConnection(ws, req) {
    const clientId = this.generateClientId();
    this.clients.set(clientId, {
      ws,
      connectedAt: new Date(),
      subscriptions: new Set()
    });
    
    // Send welcome message
    ws.send(JSON.stringify({
      type: 'connection_established',
      clientId,
      message: 'Connected to OkDriver real-time location service'
    }));
    
    console.log(`✅ Client ${clientId} connected`);
  }

  // Handle client disconnection
  handleDisconnection(ws) {
    let clientId = null;
    
    // Find and remove client
    for (const [id, client] of this.clients.entries()) {
      if (client.ws === ws) {
        clientId = id;
        
        // Remove from all vehicle subscriptions
        for (const vehicleNumber of client.subscriptions) {
          this.removeVehicleSubscription(vehicleNumber, clientId);
        }
        
        this.clients.delete(id);
        break;
      }
    }
    
    if (clientId) {
      console.log(`❌ Client ${clientId} disconnected`);
    }
  }

  // Handle incoming WebSocket messages
  handleMessage(ws, message) {
    try {
      const data = JSON.parse(message);
      
      switch (data.type) {
        case 'subscribe_vehicle':
          this.handleVehicleSubscription(ws, data.vehicleNumber);
          break;
          
        case 'unsubscribe_vehicle':
          this.handleVehicleUnsubscription(ws, data.vehicleNumber);
          break;
          
        case 'ping':
          ws.send(JSON.stringify({ type: 'pong', timestamp: Date.now() }));
          break;
          
        default:
          ws.send(JSON.stringify({ 
            type: 'error', 
            message: 'Unknown message type' 
          }));
      }
    } catch (error) {
      console.error('❌ Error handling WebSocket message:', error);
      ws.send(JSON.stringify({ 
        type: 'error', 
        message: 'Invalid message format' 
      }));
    }
  }

  // Handle vehicle subscription request
  handleVehicleSubscription(ws, vehicleNumber) {
    if (!vehicleNumber) {
      ws.send(JSON.stringify({
        type: 'error',
        message: 'Vehicle number is required'
      }));
      return;
    }

    // Find client
    let clientId = null;
    for (const [id, client] of this.clients.entries()) {
      if (client.ws === ws) {
        clientId = id;
        break;
      }
    }

    if (!clientId) {
      ws.send(JSON.stringify({
        type: 'error',
        message: 'Client not found'
      }));
      return;
    }

    // Add subscription
    this.addVehicleSubscription(vehicleNumber, clientId);
    
    // Add to client's subscriptions
    this.clients.get(clientId).subscriptions.add(vehicleNumber);
    
    ws.send(JSON.stringify({
      type: 'subscription_confirmed',
      vehicleNumber,
      message: `Subscribed to location updates for vehicle ${vehicleNumber}`
    }));
    
    console.log(`📍 Client ${clientId} subscribed to vehicle ${vehicleNumber}`);
  }

  // Handle vehicle unsubscription request
  handleVehicleUnsubscription(ws, vehicleNumber) {
    let clientId = null;
    
    // Find client
    for (const [id, client] of this.clients.entries()) {
      if (client.ws === ws) {
        clientId = id;
        break;
      }
    }

    if (!clientId) {
      ws.send(JSON.stringify({
        type: 'error',
        message: 'Client not found'
      }));
      return;
    }

    // Remove subscription
    this.removeVehicleSubscription(vehicleNumber, clientId);
    
    // Remove from client's subscriptions
    this.clients.get(clientId).subscriptions.delete(vehicleNumber);
    
    ws.send(JSON.stringify({
      type: 'unsubscription_confirmed',
      vehicleNumber,
      message: `Unsubscribed from location updates for vehicle ${vehicleNumber}`
    }));
    
    console.log(`📍 Client ${clientId} unsubscribed from vehicle ${vehicleNumber}`);
  }

  // Add vehicle subscription
  addVehicleSubscription(vehicleNumber, clientId) {
    if (!this.vehicleSubscriptions.has(vehicleNumber)) {
      this.vehicleSubscriptions.set(vehicleNumber, new Set());
    }
    this.vehicleSubscriptions.get(vehicleNumber).add(clientId);
  }

  // Remove vehicle subscription
  removeVehicleSubscription(vehicleNumber, clientId) {
    if (this.vehicleSubscriptions.has(vehicleNumber)) {
      this.vehicleSubscriptions.get(vehicleNumber).delete(clientId);
      
      // Remove vehicle entry if no subscribers
      if (this.vehicleSubscriptions.get(vehicleNumber).size === 0) {
        this.vehicleSubscriptions.delete(vehicleNumber);
      }
    }
  }

  // Broadcast location update to subscribed clients
  broadcastLocationUpdate(vehicleNumber, locationData) {
    if (!this.vehicleSubscriptions.has(vehicleNumber)) {
      return; // No subscribers for this vehicle
    }

    const message = JSON.stringify({
      type: 'location_update',
      vehicleNumber,
      data: locationData,
      timestamp: Date.now()
    });

    const subscribers = this.vehicleSubscriptions.get(vehicleNumber);
    let deliveredCount = 0;

    for (const clientId of subscribers) {
      const client = this.clients.get(clientId);
      if (client && client.ws.readyState === WebSocket.OPEN) {
        try {
          client.ws.send(message);
          deliveredCount++;
        } catch (error) {
          console.error(`❌ Failed to send location update to client ${clientId}:`, error);
          // Remove failed client
          this.removeVehicleSubscription(vehicleNumber, clientId);
          this.clients.delete(clientId);
        }
      }
    }

    if (deliveredCount > 0) {
      console.log(`📡 Location update broadcasted to ${deliveredCount} clients for vehicle ${vehicleNumber}`);
    }
  }

  // Get connection statistics
  getStats() {
    return {
      totalClients: this.clients.size,
      totalSubscriptions: Array.from(this.vehicleSubscriptions.values())
        .reduce((total, subscribers) => total + subscribers.size, 0),
      vehiclesWithSubscribers: this.vehicleSubscriptions.size
    };
  }

  // Generate unique client ID
  generateClientId() {
    return `client_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}

// Create singleton instance
const webSocketService = new WebSocketService();

module.exports = webSocketService;
