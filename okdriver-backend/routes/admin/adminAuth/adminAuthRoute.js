const express = require('express');
const { registerAdmin} = require('../../../controller/admin/adminAuth/adminRegistration');
const { loginAdmin} = require('../../../controller/admin/adminAuth/adminLogin');
const verifyAdminAuth = require('../../../middleware/verifyAdminAuth');


const router = express.Router();

// Admin Auth Routes
router.post('/register', registerAdmin);
router.post('/login', loginAdmin);



module.exports = router;
