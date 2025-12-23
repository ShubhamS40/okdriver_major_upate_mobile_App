const express = require('express');
const router = express.Router();
const paymentController = require('../../controller/user/paymentController');

// Create payment order (no JWT required; request carries userId explicitly)
router.post('/order', paymentController.createPaymentOrder);

// Payment callbacks
router.post('/success', paymentController.handlePaymentSuccess);
router.post('/failure', paymentController.handlePaymentFailure);

module.exports = router;