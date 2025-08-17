// routes/driverAuth.js
const express = require('express');
const router = express.Router();
const { registerNewUser } = require('../../controller/DriverAuth/driverRegistrationController');

router.post('/register', registerNewUser);
module.exports = router;
