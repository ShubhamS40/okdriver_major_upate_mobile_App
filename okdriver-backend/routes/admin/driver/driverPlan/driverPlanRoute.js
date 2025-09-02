const express = require('express');
const router = express.Router();

// Controllers
const { 
  createDriverPlan, 
  updateDriverPlan, 
  deleteDriverPlan, 
  getAllDriverPlans 
} = require('../../../../controller/admin/driver/driverPlan/index.js');

// @route   POST /api/driver-plans
// @desc    Create a new DriverPlan
// @access  Admin (authentication middleware can be added)
router.post('/driver-plans', createDriverPlan);

// @route   PUT /api/driver-plans/:id
// @desc    Update an existing DriverPlan
// @access  Admin
router.put('/driver-plans/:id', updateDriverPlan);

// @route   DELETE /api/driver-plans/:id
// @desc    Delete a DriverPlan by ID
// @access  Admin
router.delete('/driver-plans/:id', deleteDriverPlan);

// @route   GET /api/driver-plans
// @desc    Get all DriverPlans
// @access  Public/Admin
router.get('/driver-plans', getAllDriverPlans);

module.exports = router;
