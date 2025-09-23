const express = require('express');
const { registerCompany } = require('../../../controller/company/CompanyAuth/comapnyRegisterController.js');
const { loginCompany } = require('../../../controller/company/CompanyAuth/companyLoginController.js');
const { getCompanyPlan } = require('../../../controller/company/CompanyAuth/getCompanyPlanDetailController.js');



const router = express.Router();

router.post('/register', registerCompany);
router.post('/login', loginCompany);
router.get('/plan', getCompanyPlan);
// router.post('/vehicle', authMiddleware, addVehicle);

module.exports = router;
