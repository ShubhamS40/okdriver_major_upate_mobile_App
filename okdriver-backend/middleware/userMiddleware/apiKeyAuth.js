const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Middleware to verify API key authentication
 * This middleware checks for API key in Authorization header or x-api-key header
 * and validates it against the database
 */
const verifyApiKey = async (req, res, next) => {
  try {
    // Get API key from headers
    const authHeader = req.headers.authorization;
    const apiKeyHeader = req.headers['x-api-key'];
    
    let apiKey = null;
    
    // Check Authorization header (Bearer token format)
    if (authHeader && authHeader.startsWith('Bearer ')) {
      apiKey = authHeader.substring(7);
    }
    // Check x-api-key header
    else if (apiKeyHeader) {
      apiKey = apiKeyHeader;
    }
    
    if (!apiKey) {
      return res.status(401).json({
        success: false,
        error: 'API key required',
        message: 'Please provide API key in Authorization header (Bearer token) or x-api-key header'
      });
    }
    
    // Find API key in database
    const userApiKey = await prisma.userApiKey.findUnique({
      where: {
        apiKey: apiKey
      },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            name: true,
            emailVerified: true
          }
        }
      }
    });
    
    if (!userApiKey) {
      return res.status(401).json({
        success: false,
        error: 'Invalid API key',
        message: 'The provided API key is not valid'
      });
    }
    
    // Check if API key is active and not revoked
    if (!userApiKey.isActive || userApiKey.revoked) {
      return res.status(401).json({
        success: false,
        error: 'API key inactive or revoked',
        message: 'This API key has been deactivated or revoked'
      });
    }
    
    // Check if API key has expired
    if (userApiKey.expiresAt && new Date() > new Date(userApiKey.expiresAt)) {
      return res.status(401).json({
        success: false,
        error: 'API key expired',
        message: 'This API key has expired'
      });
    }
    
    // Update last used timestamp
    await prisma.userApiKey.update({
      where: {
        id: userApiKey.id
      },
      data: {
        lastUsedAt: new Date()
      }
    });

    // Check for active subscription (UserApiSubscription with endAt)
    const subscription = await prisma.userApiSubscription.findFirst({
      where: {
        userId: userApiKey.user.id,
        status: 'ACTIVE',
        endAt: { gte: new Date() }
      },
      orderBy: {
        endAt: 'desc'
      }
    });
    
    if (!subscription) {
      return res.status(402).json({
        success: false,
        error: 'No active subscription',
        message: 'Your plan has expired. Please purchase a plan to continue using the API.'
      });
    }
    
    // Add user info and subscription to request object
    req.user = {
      id: userApiKey.user.id,
      email: userApiKey.user.email,
      name: userApiKey.user.name,
      emailVerified: userApiKey.user.emailVerified,
      apiKeyId: userApiKey.id,
      apiKeyName: userApiKey.keyName
    };
    req.subscription = subscription;
    
    next();
    
  } catch (error) {
    console.error('API key verification error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
      message: 'Error verifying API key'
    });
  }
};

/**
 * Optional middleware to verify API key (doesn't fail if no key provided)
 * Useful for endpoints that can work with or without authentication
 */
const optionalApiKeyAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    const apiKeyHeader = req.headers['x-api-key'];
    
    let apiKey = null;
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      apiKey = authHeader.substring(7);
    } else if (apiKeyHeader) {
      apiKey = apiKeyHeader;
    }
    
    if (!apiKey) {
      // No API key provided, continue without authentication
      req.user = null;
      return next();
    }
    
    // Verify API key if provided
    const userApiKey = await prisma.userApiKey.findUnique({
      where: {
        apiKey: apiKey
      },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            name: true,
            emailVerified: true
          }
        }
      }
    });
    
    if (userApiKey && userApiKey.isActive && !userApiKey.revoked) {
      if (!userApiKey.expiresAt || new Date() <= new Date(userApiKey.expiresAt)) {
        // Update last used timestamp
        await prisma.userApiKey.update({
          where: {
            id: userApiKey.id
          },
          data: {
            lastUsedAt: new Date()
          }
        });
        
        req.user = {
          id: userApiKey.user.id,
          email: userApiKey.user.email,
          name: userApiKey.user.name,
          emailVerified: userApiKey.user.emailVerified,
          apiKeyId: userApiKey.id,
          apiKeyName: userApiKey.keyName
        };
      }
    }
    
    next();
    
  } catch (error) {
    console.error('Optional API key verification error:', error);
    // Continue without authentication on error
    req.user = null;
    next();
  }
};

/**
 * Middleware to check if user has verified email
 * Should be used after verifyApiKey middleware
 */
const requireVerifiedEmail = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      error: 'Authentication required',
      message: 'Please provide a valid API key'
    });
  }
  
  if (!req.user.emailVerified) {
    return res.status(403).json({
      success: false,
      error: 'Email verification required',
      message: 'Please verify your email address to access this endpoint'
    });
  }
  
  next();
};

module.exports = {
  verifyApiKey,
  optionalApiKeyAuth,
  requireVerifiedEmail
};
