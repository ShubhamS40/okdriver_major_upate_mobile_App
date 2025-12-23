const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');
const prisma = new PrismaClient();

/**
 * Generate a secure API key
 */
const generateApiKey = () => {
  return 'okd_' + crypto.randomBytes(32).toString('hex');
};

/**
 * Create a new API key for a user
 */
const createApiKey = async (req, res) => {
  try {
    const { userId } = req.params;
    const { keyName } = req.body;

    if (!keyName || !keyName.trim()) {
      return res.status(400).json({
        success: false,
        error: 'Key name is required'
      });
    }

    // Get user details
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, name: true }
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    // Generate API key
    const apiKey = generateApiKey();

    // Create API key record
    const newApiKey = await prisma.userApiKey.create({
      data: {
        userId: user.id,
        userEmail: user.email,
        keyName: keyName.trim(),
        apiKey: apiKey,
        isActive: true,
        revoked: false
      }
    });

    res.status(201).json({
      success: true,
      apiKey: newApiKey
    });

  } catch (error) {
    console.error('Error creating API key:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
};

/**
 * Get all API keys for a user
 */
const getUserApiKeys = async (req, res) => {
  try {
    const { userId } = req.params;

    const apiKeys = await prisma.userApiKey.findMany({
      where: { userId: userId },
      orderBy: { createdAt: 'desc' }
    });

    res.json({
      success: true,
      apiKeys: apiKeys
    });

  } catch (error) {
    console.error('Error fetching API keys:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
};

/**
 * Deactivate an API key
 */
const deactivateApiKey = async (req, res) => {
  try {
    const { userId, keyId } = req.params;

    const apiKey = await prisma.userApiKey.findFirst({
      where: {
        id: keyId,
        userId: userId
      }
    });

    if (!apiKey) {
      return res.status(404).json({
        success: false,
        error: 'API key not found'
      });
    }

    await prisma.userApiKey.update({
      where: { id: keyId },
      data: { 
        isActive: false,
        revoked: true
      }
    });

    res.json({
      success: true,
      message: 'API key deactivated successfully'
    });

  } catch (error) {
    console.error('Error deactivating API key:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
};

/**
 * Get user profile with API keys
 */
const getUserProfile = async (req, res) => {
  try {
    const { userId } = req.params;

    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        apiKeys: {
          orderBy: { createdAt: 'desc' }
        }
      }
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    res.json({
      success: true,
      user: user
    });

  } catch (error) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
};

module.exports = {
  createApiKey,
  getUserApiKeys,
  deactivateApiKey,
  getUserProfile
};
