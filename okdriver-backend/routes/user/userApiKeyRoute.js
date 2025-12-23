const express = require('express');
const router = express.Router();
const { 
  createApiKey, 
  getUserApiKeys, 
  deactivateApiKey, 
  getUserProfile 
} = require('./../../controller/user/userApiKeyController');

// Get user profile with API keys
router.get('/profile/:userId', getUserProfile);

// Create new API key
router.post('/api-key/:userId', createApiKey);

// Get all API keys for user
router.get('/api-key/:userId', getUserApiKeys);

// Deactivate API key
router.put('/api-key/:userId/:keyId/deactivate', deactivateApiKey);

module.exports = router;
