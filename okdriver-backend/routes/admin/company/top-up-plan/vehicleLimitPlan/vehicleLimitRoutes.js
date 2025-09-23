const express = require('express');
const router = express.Router();

// Import controllers
const { createVehicleLimitPlan } = require('../../../../../controller/admin/company/top_up_Plan/vehicle-limit-plan/createVehicleLimitPlanController');
const { getVehicleLimitPlans } = require('../../../../../controller/admin/company/top_up_Plan/vehicle-limit-plan/getVehicleLimitAllPlanController');
const { getVehicleLimitPlanById } = require('../../../../../controller/admin/company/top_up_Plan/vehicle-limit-plan/getVehicleLimitPlanById.controller');
const { updateVehicleLimitPlan } = require('../../../../../controller/admin/company/top_up_Plan/vehicle-limit-plan/updateVehicleLimitPlan.controller');
const { deleteVehicleLimitPlan } = require('../../../../../controller/admin/company/top_up_Plan/vehicle-limit-plan/deleteVehicleLimitPlan.controller');

// Payment controllers
const { createVehicleLimitPaymentOrder } = require('../../../../../controller/payment/verifyVehicleLimitPurchase');
const { verifyVehicleLimitPayment } = require('../../../../../controller/payment/verifyVehicleLimitPayment');

// Middleware
const { verifyCompanyAuth } = require('../../../../../middleware/companyAuth');

// Routes
// Create a new vehicle limit plan
router.post('/vehicle-limit-plans', createVehicleLimitPlan);

// Get all vehicle limit plans
router.get('/vehicle-limit-plans', getVehicleLimitPlans);

// Get vehicle limit plan by ID
router.get('/vehicle-limit-plans/:id', getVehicleLimitPlanById);

// Update a vehicle limit plan
router.put('/vehicle-limit-plans/:id', updateVehicleLimitPlan);

// Delete a vehicle limit plan
router.delete('/vehicle-limit-plans/:id', deleteVehicleLimitPlan);

/* ------------------ PAYMENT ROUTES ------------------ */
// COMPANY: Create payment order for vehicle limit top-up
router.post('/payment/create-order', verifyCompanyAuth, createVehicleLimitPaymentOrder);

// COMPANY: Verify payment for vehicle limit top-up
router.post('/payment/verify', verifyCompanyAuth, verifyVehicleLimitPayment);

// PAYU return (surl/furl) posts here without auth
router.post('/payment/payu-return', verifyVehicleLimitPayment);
// Handle GET requests for PayU return URL
router.get('/payment/payu-return', verifyVehicleLimitPayment);

module.exports = router;
