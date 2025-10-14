const express = require('express');
const router = express.Router();

// Controllers
const { createPaymentOrder } = require('../../../controller/payment/driverPayment/driverPurchasePayment');
const { verifyPayment } = require('../../../controller/payment/driverPayment/verifyDriverPayment');

// Create PayU order
router.post('/payu/create', createPaymentOrder);

// PayU return URL (surl/furl)
router.post('/payu-return', verifyPayment);

module.exports = router;


