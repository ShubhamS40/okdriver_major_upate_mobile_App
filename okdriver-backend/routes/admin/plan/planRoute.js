const express = require('express');
const { createPlan } = require('../../../controller/admin/Plan/planCreationController.js');
const { listPlans } = require('../../../controller/admin/Plan/planListController.js');
const { selectPlan } = require('../../../controller/admin/Plan/companyPlanController.js');
const verifyAdminAuth = require('../../../middleware/verifyAdminAuth.js');
const { verifyCompanyAuth } = require('../../../middleware/companyAuth.js');

// Payment Controller
const { createPaymentOrder } = require('./../../../controller/payment/companyPurchasePayment.js');
const {  verifyPayment } = require('./../../../controller/payment/verifyCompanyPayment.js');

const router = express.Router();

/* ------------------ PLAN ROUTES ------------------ */
// ADMIN: Only authenticated admins can create plans
router.post('/creation', verifyAdminAuth, createPlan);

// PUBLIC: List available plans
router.get('/list', listPlans);

// COMPANY: Select a plan (JWT required)
router.post('/select', verifyCompanyAuth, selectPlan);

/* ------------------ PAYMENT ROUTES ------------------ */
// COMPANY: Create payment order
router.post('/payment/order', verifyCompanyAuth, createPaymentOrder);

// COMPANY: Verify payment
router.post('/payment/verify', verifyCompanyAuth, verifyPayment);

module.exports = router;
