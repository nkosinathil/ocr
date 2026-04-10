<?php
declare(strict_types=1);

namespace MxaOcr\Config;

/**
 * Authentication Configuration
 * 
 * Manages Keycloak OIDC authentication configuration for MXA OCR.
 */
class Auth
{
    private static ?Auth $instance = null;
    private array $config = [];
    
    private function __construct()
    {
        $env = Environment::getInstance();
        
        $this->config = [
            'keycloak_url' => $env->getConfig('keycloak.url'),
            'realm' => $env->getConfig('keycloak.realm'),
            'client_id' => $env->getConfig('keycloak.client_id'),
            'client_secret' => $env->getConfig('keycloak.client_secret'),
            'redirect_uri' => $env->getConfig('keycloak.redirect_uri'),
            'scopes' => 'openid profile email',
            'response_type' => 'code',
            'grant_type' => 'authorization_code',
        ];
    }
    
    /**
     * Get singleton instance
     */
    public static function getInstance(): self
    {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    /**
     * Get authorization URL for OIDC flow
     */
    public function getAuthorizationUrl(string $state = null): string
    {
        if ($state === null) {
            $state = bin2hex(random_bytes(16));
        }
        
        $_SESSION['oauth_state'] = $state;
        
        $params = http_build_query([
            'client_id' => $this->config['client_id'],
            'redirect_uri' => $this->config['redirect_uri'],
            'response_type' => $this->config['response_type'],
            'scope' => $this->config['scopes'],
            'state' => $state,
        ]);
        
        return $this->getKeycloakUrl() . '/protocol/openid-connect/auth?' . $params;
    }
    
    /**
     * Get token endpoint URL
     */
    public function getTokenUrl(): string
    {
        return $this->getKeycloakUrl() . '/protocol/openid-connect/token';
    }
    
    /**
     * Get userinfo endpoint URL
     */
    public function getUserInfoUrl(): string
    {
        return $this->getKeycloakUrl() . '/protocol/openid-connect/userinfo';
    }
    
    /**
     * Get logout endpoint URL
     */
    public function getLogoutUrl(string $redirectUri = null): string
    {
        $params = [];
        if ($redirectUri) {
            $params['redirect_uri'] = $redirectUri;
        }
        
        $query = !empty($params) ? '?' . http_build_query($params) : '';
        return $this->getKeycloakUrl() . '/protocol/openid-connect/logout' . $query;
    }
    
    /**
     * Get base Keycloak realm URL
     */
    private function getKeycloakUrl(): string
    {
        return sprintf(
            '%s/realms/%s',
            rtrim($this->config['keycloak_url'], '/'),
            $this->config['realm']
        );
    }
    
    /**
     * Get configuration value
     */
    public function get(string $key, mixed $default = null): mixed
    {
        return $this->config[$key] ?? $default;
    }
    
    /**
     * Exchange authorization code for tokens
     */
    public function exchangeCodeForTokens(string $code): ?array
    {
        $params = [
            'grant_type' => $this->config['grant_type'],
            'client_id' => $this->config['client_id'],
            'client_secret' => $this->config['client_secret'],
            'code' => $code,
            'redirect_uri' => $this->config['redirect_uri'],
        ];
        
        $ch = curl_init($this->getTokenUrl());
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => http_build_query($params),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => ['Content-Type: application/x-www-form-urlencoded'],
            CURLOPT_SSL_VERIFYPEER => true,
        ]);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode === 200 && $response) {
            return json_decode($response, true);
        }
        
        error_log("Token exchange failed: HTTP $httpCode, Response: $response");
        return null;
    }
    
    /**
     * Get user info from access token
     */
    public function getUserInfo(string $accessToken): ?array
    {
        $ch = curl_init($this->getUserInfoUrl());
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => [
                'Authorization: Bearer ' . $accessToken,
                'Accept: application/json',
            ],
            CURLOPT_SSL_VERIFYPEER => true,
        ]);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode === 200 && $response) {
            return json_decode($response, true);
        }
        
        error_log("UserInfo fetch failed: HTTP $httpCode");
        return null;
    }
    
    /**
     * Refresh access token
     */
    public function refreshToken(string $refreshToken): ?array
    {
        $params = [
            'grant_type' => 'refresh_token',
            'client_id' => $this->config['client_id'],
            'client_secret' => $this->config['client_secret'],
            'refresh_token' => $refreshToken,
        ];
        
        $ch = curl_init($this->getTokenUrl());
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => http_build_query($params),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => ['Content-Type: application/x-www-form-urlencoded'],
            CURLOPT_SSL_VERIFYPEER => true,
        ]);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode === 200 && $response) {
            return json_decode($response, true);
        }
        
        return null;
    }
    
    /**
     * Parse JWT token (without verification - for claims extraction only)
     */
    public function parseToken(string $token): ?array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            return null;
        }
        
        $payload = base64_decode(strtr($parts[1], '-_', '+/'));
        return json_decode($payload, true);
    }
}
