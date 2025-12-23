const express = require('express');
const router = express.Router();

const { createApiPlan, getApiPlans, updateApiPlan, deleteApiPlan } = require('../../../controller/admin/apiPlan/index');
const verifyAdminAuth = require('../../../middleware/verifyAdminAuth');

// List
router.get('/', getApiPlans);

// Create (admin only)
router.post('/', verifyAdminAuth, createApiPlan);

// Update (admin only)
router.put('/:id', verifyAdminAuth, updateApiPlan);

// Delete (admin only)
router.delete('/:id', verifyAdminAuth, deleteApiPlan);

module.exports = router;


