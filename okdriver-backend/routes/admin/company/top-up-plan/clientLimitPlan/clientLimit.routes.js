const express = require('express');
const router = express.Router();

// Import controllers
const { createClientLimitPlan } = require('../../../../../controller/admin/company/top_up_Plan/client-limit-plan/createClientLimitPlan.controller');
const { getClientLimitPlans } = require('../../../../../controller/admin/company/top_up_Plan/client-limit-plan/getClientLimitPlans.controller');
const { getClientLimitPlanById } = require('../../../../../controller/admin/company/top_up_Plan/client-limit-plan/getClientLimitPlanById.controller');
const { updateClientLimitPlan } = require('../../../../../controller/admin/company/top_up_Plan/client-limit-plan/updateClientLimitPlan.controller');
const { deleteClientLimitPlan } = require('../../../../../controller/admin/company/top_up_Plan/client-limit-plan/deleteClientLimitPlan.controller');


// Routes
router.post('/client-limit-plans', createClientLimitPlan);
router.get('/client-limit-plans', getClientLimitPlans);
router.get('/client-limit-plans/:id', getClientLimitPlanById);
router.put('/client-limit-plans/:id', updateClientLimitPlan);
router.delete('/client-limit-plans/:id', deleteClientLimitPlan);


module.exports = router;
