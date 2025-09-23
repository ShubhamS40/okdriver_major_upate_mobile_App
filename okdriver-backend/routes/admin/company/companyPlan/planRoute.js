const express = require('express');
const router = express.Router();

// Controllers
const { createCompanyPlan, updateCompanyPlan, deleteCompanyPlan } = require('../../../../controller/admin/company/companyPlan/index.js');
const { getAllCompanyPlans } = require('../../../../controller/admin/company/companyPlan/getAllCompanyPlansController.js');

// Middleware
const verifyAdminAuth = require('../../../../middleware/verifyAdminAuth.js');
const { verifyCompanyAuth } = require('../../../../middleware/companyAuth.js');

// Payment Controllers
const { createPaymentOrder } = require('../../../../controller/payment/companyPurchasePayment.js');
const { verifyPayment } = require('../../../../controller/payment/verifyCompanyPayment.js');

/* ------------------ PLAN ROUTES ------------------ */
// ADMIN: Create a new plan
router.post('/creation', verifyAdminAuth, createCompanyPlan);

// ADMIN: Update an existing plan
router.put('/update/:id', verifyAdminAuth, updateCompanyPlan);

// ADMIN: Delete a plan
router.delete('/delete/:id', verifyAdminAuth, deleteCompanyPlan);

// PUBLIC: List all available plans
router.get('/list', getAllCompanyPlans);

// COMPANY: Select a plan
// router.post('/select', verifyCompanyAuth, selectPlan);

/* ------------------ PAYMENT ROUTES ------------------ */
// COMPANY: Create payment order
router.post('/payment/order', verifyCompanyAuth, createPaymentOrder);

// COMPANY: Verify payment
router.post('/payment/verify', verifyCompanyAuth, verifyPayment);

// PAYU return (surl/furl) posts here without auth
router.post('/payment/payu-return', verifyPayment);

module.exports = router;
