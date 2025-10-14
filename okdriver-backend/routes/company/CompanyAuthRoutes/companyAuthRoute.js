const express = require('express');
const { registerCompany } = require('../../../controller/company/CompanyAuth/comapnyRegisterController.js');
const { loginCompany } = require('../../../controller/company/CompanyAuth/companyLoginController.js');
const { getCompanyPlan } = require('../../../controller/company/CompanyAuth/getCompanyPlanDetailController.js');
const { forgotPassword, verifyResetToken, resetPassword } = require('../../../controller/company/CompanyAuth/forgotPasswordController.js');

const router = express.Router();

router.post('/register', registerCompany);
router.post('/login', loginCompany);
router.get('/plan', getCompanyPlan);
// router.post('/vehicle', authMiddleware, addVehicle);

// Password reset routes
router.post('/forgot-password', forgotPassword);
router.get('/verify-reset-token', verifyResetToken);
router.post('/reset-password', resetPassword);

module.exports = router;
