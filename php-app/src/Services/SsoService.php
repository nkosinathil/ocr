<?php

declare(strict_types=1);

namespace App\Services;

use RuntimeException;

class SsoService
{
    private string $serverUrl;
    private string $clientId;
    private string $clientSecret;
    private string $redirectUri;

    public function __construct(array $ssoConfig)
    {
        $this->serverUrl = rtrim($ssoConfig['server_url'] ?? '', '/');
        $this->clientId = $ssoConfig['client_id'] ?? '';
        $this->clientSecret = $ssoConfig['client_secret'] ?? '';
        $this->redirectUri = $ssoConfig['redirect_uri'] ?? '';

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
            'scope'         => 'openid profile email',
            'state'         => $state,
        ];

        return $this->serverUrl . '/authorize?' . http_build_query($params);
    }

    /**
     * @return array{access_token: string, token_type: string, expires_in: int, refresh_token?: string}
     */
    public function exchangeCode(string $code): array
    {
        $url = $this->serverUrl . '/token';

        $postFields = [
            'grant_type'    => 'authorization_code',
            'code'          => $code,
            'redirect_uri'  => $this->redirectUri,
            'client_id'     => $this->clientId,
            'client_secret' => $this->clientSecret,
        ];

        $response = $this->httpPost($url, $postFields);

        if (isset($response['error'])) {
            throw new RuntimeException('SSO token exchange failed: ' . ($response['error_description'] ?? $response['error']));
        }

        return $response;
    }

    /**
     * @return array{sub: string, email: string, name: string, preferred_username?: string}
     */
    public function verifyToken(string $token): array
    {
        $url = $this->serverUrl . '/token/introspect';

        $response = $this->httpPost($url, [
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
        $url = $this->serverUrl . '/userinfo';

        $response = $this->httpGet($url, $accessToken);

        if (isset($response['error'])) {
            throw new RuntimeException('Failed to get user info: ' . ($response['error_description'] ?? $response['error']));
        }

        return $response;
    }

    public function revokeToken(string $token): void
    {
        $url = $this->serverUrl . '/token/revoke';

        $this->httpPost($url, [
            'token'         => $token,
            'client_id'     => $this->clientId,
            'client_secret' => $this->clientSecret,
        ]);
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
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_FOLLOWLOCATION => false,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        $errno = curl_errno($ch);
        curl_close($ch);

        if ($response === false || $errno !== 0) {
            throw new RuntimeException('SSO HTTP request failed: ' . $error, $errno);
        }

        if ($httpCode >= 400) {
            throw new RuntimeException("SSO server returned HTTP {$httpCode}: " . $response);
        }

        $decoded = json_decode($response, true);
        if (!is_array($decoded)) {
            throw new RuntimeException('Invalid JSON response from SSO server');
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
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_FOLLOWLOCATION => false,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        $errno = curl_errno($ch);
        curl_close($ch);

        if ($response === false || $errno !== 0) {
            throw new RuntimeException('SSO HTTP GET request failed: ' . $error, $errno);
        }

        if ($httpCode >= 400) {
            throw new RuntimeException("SSO server returned HTTP {$httpCode}: " . $response);
        }

        $decoded = json_decode($response, true);
        if (!is_array($decoded)) {
            throw new RuntimeException('Invalid JSON response from SSO server');
        }

        return $decoded;
    }
}
