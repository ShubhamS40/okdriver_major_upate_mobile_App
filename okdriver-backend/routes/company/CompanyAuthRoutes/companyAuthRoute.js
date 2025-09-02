const express = require('express');
const { registerCompany } = require('../../../controller/company/CompanyAuth/comapnyRegisterController.js');
const { loginCompany } = require('../../../controller/company/CompanyAuth/companyLoginController.js');



const router = express.Router();

router.post('/register', registerCompany);
router.post('/login', loginCompany);
// router.post('/vehicle', authMiddleware, addVehicle);

module.exports = router;
