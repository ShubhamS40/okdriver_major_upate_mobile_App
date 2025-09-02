const express = require('express');
const router = express.Router();
const controller = require('../../../controller/driver/DriverVoiceAssistant/driverVoiceAssistantController');

// Chat and AI endpoints
router.post('/chat', controller.chat);
router.post('/test-ai', controller.testAI);

// TTS endpoints
router.get('/audio-status/:audioId', controller.getAudioStatus);
router.post('/test-speech', controller.testSpeech);
router.post('/test-speakers', controller.testSpeakers);

// Config and settings
router.get('/config', controller.getConfig);
router.post('/settings/:userId', controller.saveSettings);
router.get('/settings/:userId', controller.getSettings);

// History
router.get('/history', controller.getHistory);
router.get('/history/:userId', controller.getUserHistory);
router.delete('/history', controller.clearHistory);
router.delete('/history/:userId', controller.clearUserHistory);

// Health
router.get('/health', controller.health);

module.exports = router;