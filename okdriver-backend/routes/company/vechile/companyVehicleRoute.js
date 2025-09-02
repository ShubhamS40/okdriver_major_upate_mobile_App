const express = require('express');
const { addVehicle, updateVehicle, deleteVehicle, getAllVehicles } = require('../../../controller/company/vechile/route');
const { verifyCompanyAuth } = require('../../../middleware/companyAuth');

const router = express.Router();

// @route   POST /api/company/vehicles
// @desc    Add a new vehicle
router.post('/', verifyCompanyAuth, addVehicle);

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
