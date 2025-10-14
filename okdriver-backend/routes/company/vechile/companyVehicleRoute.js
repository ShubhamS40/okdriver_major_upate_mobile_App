const express = require('express');
const { addVehicle, updateVehicle, deleteVehicle, getAllVehicles, loginVehicle, updateLiveLocation, getLatestLocation, getLocationHistory, getVehicleChatHistory, sendMessageToVehicle, markMessagesAsRead, getUnreadCount, cleanupOldMessages } = require('../../../controller/company/vechile/route');
const { verifyCompanyAuth } = require('../../../middleware/companyAuth');
const companyOrVehicleAuth = require('../../../middleware/companyOrVehicleAuth');

const router = express.Router();

// @route   POST /api/company/vehicles
// @desc    Add a new vehicle
router.post('/', verifyCompanyAuth, addVehicle);

// @route   POST /api/company/vehicles/login
// @desc    Login vehicle using vehicleNumber and password
router.post('/login', loginVehicle);

// Live location routes (no auth required for fleet driver updates)
// @route   POST /api/company/vehicles/location/update
// @desc    Update live location for a vehicle (called every 5 seconds)
router.post('/location/update', updateLiveLocation);

// @route   GET /api/company/vehicles/location/:vehicleNumber
// @desc    Get latest location for a specific vehicle
router.get('/location/:vehicleNumber', getLatestLocation);

// @route   GET /api/company/vehicles/location/:vehicleNumber/history
// @desc    Get location history for a specific vehicle with pagination
router.get('/location/:vehicleNumber/history', getLocationHistory);

// @route   PUT /api/company/vehicles/:id
// @desc    Update vehicle details
router.put('/:id', verifyCompanyAuth, updateVehicle);

// @route   DELETE /api/company/vehicles/:id
// @desc    Delete a vehicle
router.delete('/:id', verifyCompanyAuth, deleteVehicle);

// @route   GET /api/company/vehicles
// @desc    Get all vehicles for the company
router.get('/', verifyCompanyAuth, getAllVehicles);

// Chat routes
// @route   GET /api/company/vehicles/:vehicleId/chat-history
// @desc    Get chat history for a specific vehicle (company or driver token)
router.get('/:vehicleId/chat-history', companyOrVehicleAuth, getVehicleChatHistory);

// @route   POST /api/company/vehicles/:vehicleId/send-message
// @desc    Send message to vehicle driver
router.post('/:vehicleId/send-message', verifyCompanyAuth, sendMessageToVehicle);

// @route   PUT /api/company/vehicles/:vehicleId/mark-read
// @desc    Mark messages as read (company or driver token)
router.put('/:vehicleId/mark-read', companyOrVehicleAuth, markMessagesAsRead);

// @route   GET /api/company/vehicles/:vehicleId/unread-count
// @desc    Get unread message count for vehicle (company or driver token)
router.get('/:vehicleId/unread-count', companyOrVehicleAuth, getUnreadCount);

// @route   DELETE /api/company/vehicles/cleanup-messages
// @desc    Clean up old messages (older than 24 hours)
router.delete('/cleanup-messages', verifyCompanyAuth, cleanupOldMessages);

// Test route
router.get('/test', (req, res) => {
  res.json({ message: 'Vehicle routes are working' });
});

// Debug route to check authentication
router.get('/debug', verifyCompanyAuth, (req, res) => {
  res.json({ 
    message: 'Authentication working',
    companyId: req.company.id,
    companyName: req.company.name
  });
});

module.exports = router;
