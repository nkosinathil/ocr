<?php

declare(strict_types=1);

namespace App\Services;

use RuntimeException;

class SsoService
{
    private string $serverUrl;
    private string $realm;
    private string $clientId;
    private string $clientSecret;
    private string $redirectUri;
    private string $authEndpoint;
    private string $tokenEndpoint;
    private string $userinfoEndpoint;
    private string $logoutEndpoint;
    private string $introspectEndpoint;
    private string $revokeEndpoint;

    public function __construct(array $ssoConfig)
    {
        $this->serverUrl  = rtrim($ssoConfig['server_url'] ?? '', '/');
        $this->realm      = $ssoConfig['realm'] ?? 'gint';
        $this->clientId   = $ssoConfig['client_id'] ?? '';
        $this->clientSecret = $ssoConfig['client_secret'] ?? '';
        $this->redirectUri  = $ssoConfig['redirect_uri'] ?? '';

        $base = $this->serverUrl . '/realms/' . $this->realm . '/protocol/openid-connect';

        $this->authEndpoint       = $ssoConfig['auth_endpoint'] ?: $base . '/auth';
        $this->tokenEndpoint      = $ssoConfig['token_endpoint'] ?: $base . '/token';
        $this->userinfoEndpoint   = $ssoConfig['userinfo_endpoint'] ?: $base . '/userinfo';
        $this->logoutEndpoint     = $ssoConfig['logout_endpoint'] ?: $base . '/logout';
        $this->introspectEndpoint = $ssoConfig['introspect_endpoint'] ?: $base . '/token/introspect';
        $this->revokeEndpoint     = $ssoConfig['revoke_endpoint'] ?: $base . '/revoke';

        if ($this->serverUrl === '' || $this->clientId === '') {
            throw new RuntimeException('SSO server URL and client ID are required');
        }
    }

    public function getAuthorizationUrl(string $state = ''): string
    {
        $params = [
            'response_type' => 'code',
            'client_id'     => $this->clientId,
            'redirect_uri'  => $this->redirectUri,
            'scope'         => 'openid profile email roles',
            'state'         => $state,
        ];

        return $this->authEndpoint . '?' . http_build_query($params);
    }

    /**
     * @return array{access_token: string, token_type: string, expires_in: int, refresh_token?: string, id_token?: string}
     */
    public function exchangeCode(string $code): array
    {
        $postFields = [
            'grant_type'    => 'authorization_code',
            'code'          => $code,
            'redirect_uri'  => $this->redirectUri,
            'client_id'     => $this->clientId,
        ];

        if ($this->clientSecret !== '') {
            $postFields['client_secret'] = $this->clientSecret;
        }

        $response = $this->httpPost($this->tokenEndpoint, $postFields);

        if (isset($response['error'])) {
            throw new RuntimeException(
                'Keycloak token exchange failed: ' . ($response['error_description'] ?? $response['error'])
            );
        }

        return $response;
    }

    /**
     * @return array{sub: string, email: string, name: string, preferred_username?: string}
     */
    public function verifyToken(string $token): array
    {
        $response = $this->httpPost($this->introspectEndpoint, [
            'token'         => $token,
            'client_id'     => $this->clientId,
            'client_secret' => $this->clientSecret,
        ]);

        if (empty($response['active'])) {
            throw new RuntimeException('Token is not active or invalid');
        }

        return $response;
    }

    /**
     * @return array{sub: string, email: string, name: string, preferred_username?: string, picture?: string}
     */
    public function getUserInfo(string $accessToken): array
    {
        $response = $this->httpGet($this->userinfoEndpoint, $accessToken);

        if (isset($response['error'])) {
            throw new RuntimeException(
                'Failed to get user info: ' . ($response['error_description'] ?? $response['error'])
            );
        }

        return $response;
    }

    public function revokeToken(string $token): void
    {
        try {
            $this->httpPost($this->revokeEndpoint, [
                'token'         => $token,
                'client_id'     => $this->clientId,
                'client_secret' => $this->clientSecret,
            ]);
        } catch (\Throwable $e) {
            error_log('Token revocation failed: ' . $e->getMessage());
        }
    }

    public function getLogoutUrl(string $idTokenHint = '', string $postLogoutRedirect = ''): string
    {
        $params = ['client_id' => $this->clientId];

        if ($idTokenHint !== '') {
            $params['id_token_hint'] = $idTokenHint;
        }
        if ($postLogoutRedirect !== '') {
            $params['post_logout_redirect_uri'] = $postLogoutRedirect;
        }

        return $this->logoutEndpoint . '?' . http_build_query($params);
    }

    private function httpPost(string $url, array $fields): array
    {
        $ch = curl_init();

        curl_setopt_array($ch, [
            CURLOPT_URL            => $url,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => http_build_query($fields),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 15,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_HTTPHEADER     => [
                'Content-Type: application/x-www-form-urlencoded',
                'Accept: application/json',
            ],
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_FOLLOWLOCATION => false,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        $errno = curl_errno($ch);
        curl_close($ch);

        if ($response === false || $errno !== 0) {
            throw new RuntimeException('Keycloak HTTP request failed: ' . $error, $errno);
        }

        if ($httpCode >= 400) {
            throw new RuntimeException("Keycloak returned HTTP {$httpCode}: " . $response);
        }

        $decoded = json_decode($response, true);
        if (!is_array($decoded)) {
            throw new RuntimeException('Invalid JSON response from Keycloak');
        }

        return $decoded;
    }

    private function httpGet(string $url, string $bearerToken): array
    {
        $ch = curl_init();

        curl_setopt_array($ch, [
            CURLOPT_URL            => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 15,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_HTTPHEADER     => [
                'Authorization: Bearer ' . $bearerToken,
                'Accept: application/json',
            ],
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_FOLLOWLOCATION => false,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        $errno = curl_errno($ch);
        curl_close($ch);

        if ($response === false || $errno !== 0) {
            throw new RuntimeException('Keycloak HTTP GET failed: ' . $error, $errno);
        }

        if ($httpCode >= 400) {
            throw new RuntimeException("Keycloak returned HTTP {$httpCode}: " . $response);
        }

        $decoded = json_decode($response, true);
        if (!is_array($decoded)) {
            throw new RuntimeException('Invalid JSON response from Keycloak');
        }

        return $decoded;
    }
}
