const express = require('express');
const { addVehicle, updateVehicle, deleteVehicle, getAllVehicles, loginVehicle, updateLiveLocation, getLatestLocation } = require('../../../controller/company/vechile/route');
const { verifyCompanyAuth } = require('../../../middleware/companyAuth');

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

// @route   PUT /api/company/vehicles/:id
// @desc    Update vehicle details
router.put('/:id', verifyCompanyAuth, updateVehicle);

// @route   DELETE /api/company/vehicles/:id
// @desc    Delete a vehicle
router.delete('/:id', verifyCompanyAuth, deleteVehicle);

// @route   GET /api/company/vehicles
// @desc    Get all vehicles for the company
router.get('/', verifyCompanyAuth, getAllVehicles);

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
