const express = require('express');
const router = express.Router();
const chatController = require('../../controller/DriverVoiceAssistant/driverVoiceAssistantController');

router.post('/chat', chatController.chat);
// Add more routes like /test-ai, /test-speech if needed

module.exports = router;