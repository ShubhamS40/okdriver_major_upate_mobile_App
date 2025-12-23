const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const prisma = new PrismaClient();

// Save or update user from Google authentication
const saveUserFromGoogle = async (req, res) => {
  try {
    const { googleId, email, name, picture, emailVerified } = req.body;

    if (!googleId || !email || !name) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: googleId, email, name'
      });
    }

    // Check if user already exists by googleId
    let user = await prisma.user.findUnique({
      where: { googleId }
    });

    if (user) {
      // Update existing Google user
      user = await prisma.user.update({
        where: { googleId },
        data: {
          email,
          name,
          picture,
          emailVerified,
          updatedAt: new Date()
        }
      });
    } else {
      // Check if user exists with same email (email/password user)
      const existingUserByEmail = await prisma.user.findUnique({
        where: { email }
      });

      if (existingUserByEmail) {
        // Update existing email/password user to add Google ID
        user = await prisma.user.update({
          where: { email },
          data: {
            googleId,
            name,
            picture,
            emailVerified,
            updatedAt: new Date()
          }
        });
      } else {
        // Create new user
        user = await prisma.user.create({
          data: {
            googleId,
            email,
            name,
            picture,
            emailVerified
          }
        });
      }
    }

    res.status(200).json({
      success: true,
      message: 'User saved successfully',
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        picture: user.picture,
        emailVerified: user.emailVerified
      }
    });
  } catch (error) {
    console.error('Error saving user:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};

// Get user profile
const getUserProfile = async (req, res) => {
  try {
    const { userId } = req.params;

    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        apiKeys: {
          where: { isActive: true },
          orderBy: { createdAt: 'desc' }
        }
      }
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Aggregate API usage count - skip this since apiUsage table doesn't exist
    const apiCalls = 0; // Default to 0 since the table doesn't exist

    res.status(200).json({
      success: true,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        picture: user.picture,
        emailVerified: user.emailVerified,
        createdAt: user.createdAt,
        apiKeys: user.apiKeys,
        apiCalls
      }
    });
  } catch (error) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};

// Create API key for user
const createApiKey = async (req, res) => {
  try {
    const { userId } = req.params;
    const { keyName } = req.body;

    if (!keyName) {
      return res.status(400).json({
        success: false,
        message: 'Key name is required'
      });
    }

    // Check if user exists
    const user = await prisma.user.findUnique({
      where: { id: userId }
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Generate API key
    const apiKey = `okd_${crypto.randomBytes(32).toString('hex')}`;
    
    // Set expiration date (1 year from now)
    const expiresAt = new Date();
    expiresAt.setFullYear(expiresAt.getFullYear() + 1);

    const newApiKey = await prisma.userApiKey.create({
      data: {
        userId,
        userEmail: user.email,
        keyName,
        apiKey,
        expiresAt
      }
    });

    res.status(201).json({
      success: true,
      message: 'API key created successfully',
      apiKey: {
        id: newApiKey.id,
        keyName: newApiKey.keyName,
        apiKey: newApiKey.apiKey,
        createdAt: newApiKey.createdAt,
        expiresAt: newApiKey.expiresAt
      }
    });
  } catch (error) {
    console.error('Error creating API key:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};

// Get user's API keys
const getUserApiKeys = async (req, res) => {
  try {
    const { userId } = req.params;

    const apiKeys = await prisma.userApiKey.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' }
    });

    res.status(200).json({
      success: true,
      apiKeys: apiKeys.map(key => ({
        id: key.id,
        keyName: key.keyName,
        apiKey: key.apiKey,
        isActive: key.isActive,
        lastUsedAt: key.lastUsedAt,
        createdAt: key.createdAt,
        expiresAt: key.expiresAt
      }))
    });
  } catch (error) {
    console.error('Error fetching API keys:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};

// Deactivate API key
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
        message: 'API key not found'
      });
    }

    await prisma.userApiKey.update({
      where: { id: keyId },
      data: { 
        isActive: false,
        revoked: true
      }
    });

    res.status(200).json({
      success: true,
      message: 'API key deactivated successfully'
    });
  } catch (error) {
    console.error('Error deactivating API key:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};

// Update user profile
const updateUserProfile = async (req, res) => {
  try {
    const { userId } = req.params;
    const { name, picture } = req.body;

    const user = await prisma.user.findUnique({
      where: { id: userId }
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: {
        name: name || user.name,
        picture: picture || user.picture,
        updatedAt: new Date()
      }
    });

    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      user: {
        id: updatedUser.id,
        email: updatedUser.email,
        name: updatedUser.name,
        picture: updatedUser.picture,
        emailVerified: updatedUser.emailVerified
      }
    });
  } catch (error) {
    console.error('Error updating user profile:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};

// Get user's current subscription (latest active)
const getUserSubscription = async (req, res) => {
  try {
    const { userId } = req.params;
    const now = new Date();
    // Get latest not-expired subscription
    const sub = await prisma.userApiSubscription.findFirst({
      where: {
        userId,
        status: 'ACTIVE',
        endAt: { gte: now },
      },
      orderBy: { endAt: 'desc' },
      include: { plan: true },
    });
    if (!sub) {
      return res.json({ success: true, subscription: null });
    }
    // Align response with frontend expectations
    return res.json({ success: true, subscription: sub });
  } catch (err) {
    console.error('getUserSubscription error:', err);
    return res.status(500).json({ success: false, message: 'internal' });
  }
};

// Subscribe (buy) an API plan
const subscribeToApiPlan = async (req, res) => {
  try {
    const { userId, planId } = req.body;
    if (!userId || !planId) return res.status(400).json({ ok: false, error: 'userId and planId required' });
    const plan = await prisma.apiPlan.findUnique({ where: { id: Number(planId) } });
    if (!plan || !plan.isActive) return res.status(404).json({ ok: false, error: 'Plan not found or inactive' });
    // Expire any other active subscription
    await prisma.userApiSubscription.updateMany({
      where: {
        userId,
        status: 'ACTIVE',
        endAt: { gte: new Date() },
      },
      data: { status: 'EXPIRED' },
    });
    // Create new subscription
    const start = new Date();
    const end = new Date(start);
    end.setDate(start.getDate() + plan.daysValidity);
    const newSub = await prisma.userApiSubscription.create({
      data: {
        userId,
        planId: plan.id,
        startAt: start,
        endAt: end,
        status: 'ACTIVE'
      },
      include: { plan: true },
    });
    res.json({ ok: true, data: newSub });
  } catch (err) {
    console.error('subscribeToApiPlan error:', err);
    res.status(500).json({ ok: false, error: 'internal' });
  }
};

// Register user with email and password
const registerUser = async (req, res) => {
  try {
    const { email, password, name } = req.body;

    // Validation
    if (!email || !password || !name) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: email, password, name'
      });
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid email format'
      });
    }

    // Validate password length
    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters long'
      });
    }

    // Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email }
    });

    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: 'User with this email already exists'
      });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create new user
    const user = await prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        name,
        emailVerified: false
      }
    });

    // Generate JWT token
    const token = jwt.sign(
      { 
        userId: user.id, 
        email: user.email,
        backendId: user.id 
      },
      process.env.JWT_SECRET || 'your-secret-key',
      { expiresIn: '7d' }
    );

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        emailVerified: user.emailVerified
      },
      token
    });
  } catch (error) {
    console.error('Error registering user:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};

// Login user with email and password
const loginUser = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validation
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required'
      });
    }

    // Find user by email
    const user = await prisma.user.findUnique({
      where: { email }
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password'
      });
    }

    // Check if user has a password (email/password user)
    if (!user.password) {
      return res.status(401).json({
        success: false,
        message: 'This account was created with Google. Please use Google sign-in.'
      });
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password);

    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password'
      });
    }

    // Generate JWT token
    const token = jwt.sign(
      { 
        userId: user.id, 
        email: user.email,
        backendId: user.id 
      },
      process.env.JWT_SECRET || 'your-secret-key',
      { expiresIn: '7d' }
    );

    res.status(200).json({
      success: true,
      message: 'Login successful',
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        picture: user.picture,
        emailVerified: user.emailVerified
      },
      token
    });
  } catch (error) {
    console.error('Error logging in user:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};

module.exports = {
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
};
