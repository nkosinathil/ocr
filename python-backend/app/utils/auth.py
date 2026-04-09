import logging
from typing import Any, Dict, Optional

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from app.config import get_settings

logger = logging.getLogger(__name__)

security = HTTPBearer(auto_error=False)


async def verify_token(token: str) -> Dict[str, Any]:
    """Verify a Keycloak access token via introspection, with local JWT fallback."""
    settings = get_settings()

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                settings.SSO_TOKEN_VERIFY_URL,
                data={
                    "token": token,
                    "client_id": "gint-ocr-platform",
                    "token_type_hint": "access_token",
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )

        if response.status_code == 200:
            data = response.json()
            if data.get("active"):
                return {
                    "user_id": data.get("sub"),
                    "email": data.get("email"),
                    "username": data.get("preferred_username") or data.get("username"),
                    "name": data.get("name"),
                    "roles": data.get("realm_access", {}).get("roles", []),
                }
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token is invalid or expired",
            )

        logger.warning("Keycloak introspection returned status %d", response.status_code)

    except httpx.RequestError:
        logger.warning("Keycloak unreachable, falling back to local JWT decode")

    try:
        payload = jwt.decode(token, options={"verify_signature": False})
        return {
            "user_id": payload.get("sub"),
            "email": payload.get("email"),
            "username": payload.get("preferred_username"),
            "name": payload.get("name"),
            "roles": payload.get("realm_access", {}).get("roles", []),
        }
    except JWTError:
        logger.exception("Failed to decode JWT locally")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
        )


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> Dict[str, Any]:
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication credentials not provided",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return await verify_token(credentials.credentials)
