const express = require('express');
const router = express.Router();
const {
  saveUserFromGoogle,
  registerUser,
  loginUser,
  getUserProfile,
  createApiKey,
  getUserApiKeys,
  deactivateApiKey,
  updateUserProfile,
  getUserSubscription,
  subscribeToApiPlan
} = require('../../controller/user/userAuthController');

// User registration with email/password
router.post('/register', registerUser);

// User login with email/password
router.post('/login', loginUser);

// Save user from Google authentication
router.post('/save-user', saveUserFromGoogle);

// Get user profile
router.get('/profile/:userId', getUserProfile);

// Update user profile
router.put('/profile/:userId', updateUserProfile);

// Create API key for user
router.post('/api-key/:userId', createApiKey);

// Get user's API keys
router.get('/api-key/:userId', getUserApiKeys);

// Deactivate API key
router.put('/api-key/:userId/:keyId/deactivate', deactivateApiKey);

// Subscription routes
router.get('/subscription/:userId', getUserSubscription);
router.post('/subscribe', subscribeToApiPlan);

module.exports = router;
