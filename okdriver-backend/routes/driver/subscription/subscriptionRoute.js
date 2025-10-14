const express = require('express');
const router = express.Router();

const { getActiveSubscription } = require('../../../controller/driver/subscription/getActiveSubscription');

router.get('/active', getActiveSubscription);

module.exports = router;


