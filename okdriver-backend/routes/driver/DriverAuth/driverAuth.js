const express = require('express');
const router = express.Router();
const { authenticateDriver } = require('../../../middleware/driverAuth');
const logoutController = require('../../../controller/driver/DriverAuth/logoutController');

// Protected routes (require authentication)
router.get('/current', authenticateDriver, logoutController.getCurrentDriver);
router.post('/logout', authenticateDriver, logoutController.logout);

module.exports = router; 