const express = require('express');
const router = express.Router();
const { generateOkDriverResponse } = require('./../../controller/user/userChatController');
const { verifyApiKey } = require('./../../middleware/userMiddleware/apiKeyAuth');

router.post('/chat', verifyApiKey, generateOkDriverResponse);

module.exports = router;

