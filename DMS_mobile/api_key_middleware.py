import asyncio
from datetime import datetime, timezone
import asyncpg
import os
from fastapi import HTTPException, Depends, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Optional
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database connection
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:Shubham2004@database-2.cnaai6c2ubaq.ap-south-1.rds.amazonaws.com:5432/postgres")

class DatabaseManager:
    def __init__(self):
        self.pool = None
    
    async def init_pool(self):
        if not self.pool:
            self.pool = await asyncpg.create_pool(DATABASE_URL)
    
    async def close_pool(self):
        if self.pool:
            await self.pool.close()
    
    async def execute_query(self, query: str, *args):
        if not self.pool:
            await self.init_pool()
        
        async with self.pool.acquire() as conn:
            return await conn.fetchrow(query, *args)

    async def execute_fetch(self, query: str, *args):
        if not self.pool:
            await self.init_pool()
        async with self.pool.acquire() as conn:
            return await conn.fetch(query, *args)

db_manager = DatabaseManager()

# Security scheme
security = HTTPBearer(auto_error=False)

def _to_aware_utc(dt: datetime) -> datetime:
    """Return a timezone-aware UTC datetime given a possibly-naive datetime."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)

async def verify_api_key(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
) -> dict:
    """
    FastAPI dependency to verify API key authentication
    """
    api_key = None
    
    # Check Authorization header (Bearer token)
    if credentials:
        api_key = credentials.credentials
    else:
        # Check x-api-key header
        api_key = request.headers.get("x-api-key")
    
    if not api_key:
        raise HTTPException(
            status_code=401,
            detail={
                "success": False,
                "error": "API key required",
                "message": "Please provide API key in Authorization header (Bearer token) or x-api-key header"
            }
        )
    
    try:
        # Query database for API key with subscription information
        query = """
        SELECT 
            uak."id"                AS id,
            uak."keyName"           AS key_name,
            uak."apiKey"            AS api_key,
            uak."isActive"          AS is_active,
            uak."revoked"           AS revoked,
            uak."lastUsedAt"        AS last_used_at,
            uak."expiresAt"         AS expires_at,
            u.id                     AS user_id,
            u.email                  AS email,
            u.name                   AS name,
            u."emailVerified"       AS email_verified,
            s.id                     AS subscription_id,
            s.status                 AS subscription_status,
            s."endAt"               AS subscription_expires_at,
            p."name"                AS plan_name
        FROM "UserApiKey" uak
        JOIN "User" u ON uak."userId" = u.id
        LEFT JOIN LATERAL (
            SELECT sus.*
            FROM "UserApiSubscription" sus
            WHERE sus."userId" = u.id 
              AND sus.status = 'ACTIVE'
              AND sus."endAt" >= NOW()
            ORDER BY sus."endAt" DESC
            LIMIT 1
        ) s ON TRUE
        LEFT JOIN "ApiPlan" p ON p.id = s."planId"
        WHERE uak."apiKey" = $1
        """
        
        result = await db_manager.execute_query(query, api_key)
        
        if not result:
            raise HTTPException(
                status_code=401,
                detail={
                    "success": False,
                    "error": "Invalid API key",
                    "message": "The provided API key is not valid"
                }
            )
        
        # Check if API key is active and not revoked
        if not result['is_active'] or result['revoked']:
            raise HTTPException(
                status_code=401,
                detail={
                    "success": False,
                    "error": "API key inactive or revoked",
                    "message": "This API key has been deactivated or revoked"
                }
            )
        
        # Check if API key has expired
        expires_at_utc = _to_aware_utc(result['expires_at']) if result['expires_at'] else None
        if expires_at_utc and expires_at_utc < datetime.now(timezone.utc):
            raise HTTPException(
                status_code=401,
                detail={
                    "success": False,
                    "error": "API key expired",
                    "message": "This API key has expired"
                }
            )
        
        # Update last used timestamp
        update_query = """
        UPDATE "UserApiKey" 
        SET "lastUsedAt" = NOW() 
        WHERE id = $1
        """
        await db_manager.execute_query(update_query, result['id'])

        # Check if user has an active subscription
        if not result['subscription_id']:
            raise HTTPException(
                status_code=402,
                detail={
                    "success": False,
                    "error": "No active subscription",
                    "message": "Your plan has expired. Please purchase a plan to continue using the API."
                }
            )
        
        # Check if subscription is expired
        sub_expires_at = _to_aware_utc(result['subscription_expires_at']) if result['subscription_expires_at'] else None
        if sub_expires_at and sub_expires_at < datetime.now(timezone.utc):
            raise HTTPException(
                status_code=402,
                detail={
                    "success": False,
                    "error": "Subscription expired",
                    "message": "Your plan has expired. Please renew your subscription to continue using the API."
                }
            )
        
        # Return user info with subscription details
        return {
            "user_id": result['user_id'],
            "email": result['email'],
            "name": result['name'],
            "email_verified": result['email_verified'],
            "api_key_id": result['id'],
            "api_key_name": result['key_name'],
            "subscription": {
                "id": result['subscription_id'],
                "status": result['subscription_status'],
                "expires_at": result['subscription_expires_at'],
                "plan_name": result['plan_name']
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"API key verification error: {e}")
        raise HTTPException(
            status_code=500,
            detail={
                "success": False,
                "error": "Internal server error",
                "message": "Error verifying API key"
            }
        )

async def optional_api_key_auth(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
) -> Optional[dict]:
    """
    Optional API key authentication - doesn't fail if no key provided
    """
    api_key = None
    
    if credentials:
        api_key = credentials.credentials
    else:
        api_key = request.headers.get("x-api-key")
    
    if not api_key:
        return None
    
    try:
        query = """
        SELECT 
            uak."id"                AS id,
            uak."keyName"           AS key_name,
            uak."apiKey"            AS api_key,
            uak."isActive"          AS is_active,
            uak."revoked"           AS revoked,
            uak."lastUsedAt"        AS last_used_at,
            uak."expiresAt"         AS expires_at,
            u.id                     AS user_id,
            u.email                  AS email,
            u.name                   AS name,
            u."emailVerified"       AS email_verified
        FROM "UserApiKey" uak
        JOIN "User" u ON uak."userId" = u.id
        WHERE uak."apiKey" = $1
        """
        
        result = await db_manager.execute_query(query, api_key)
        
        if result and result['is_active'] and not result['revoked']:
            expires_at_utc = _to_aware_utc(result['expires_at']) if result['expires_at'] else None
            if not expires_at_utc or expires_at_utc >= datetime.now(timezone.utc):
                # Update last used timestamp
                update_query = """
                UPDATE "UserApiKey" 
                SET "lastUsedAt" = NOW() 
                WHERE id = $1
                """
                await db_manager.execute_query(update_query, result['id'])
                
                # Optional soft charge (ignore failures)
                try:
                    # No wallet/balance/ApiWallet logic here
                    # No ApiUsage logic here
                    pass # Removed wallet/usage logic
                except Exception:
                    pass
                
                return {
                    "user_id": result['user_id'],
                    "email": result['email'],
                    "name": result['name'],
                    "email_verified": result['email_verified'],
                    "api_key_id": result['id'],
                    "api_key_name": result['key_name']
                }
        
        return None
        
    except Exception as e:
        logger.error(f"Optional API key verification error: {e}")
        return None

def require_verified_email(user: dict = Depends(verify_api_key)) -> dict:
    """
    Dependency to ensure user has verified email
    """
    if not user.get('email_verified'):
        raise HTTPException(
            status_code=403,
            detail={
                "success": False,
                "error": "Email verification required",
                "message": "Please verify your email address to access this endpoint"
            }
        )
    return user

# Initialize database connection on startup
async def init_database():
    await db_manager.init_pool()
    logger.info("Database connection pool initialized")

# Cleanup database connection on shutdown
async def cleanup_database():
    await db_manager.close_pool()
    logger.info("Database connection pool closed")
