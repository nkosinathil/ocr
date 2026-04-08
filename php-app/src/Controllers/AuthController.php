<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Services\SsoService;
use App\Models\User;

class AuthController
{
    private SsoService $ssoService;
    private array $config;

    public function __construct(array $config)
    {
        $this->config = $config;
        $this->ssoService = new SsoService($config['sso']);
    }

    public function login(): void
    {
        if (isset($_SESSION['user'])) {
            header('Location: /');
            exit;
        }

        $state = bin2hex(random_bytes(32));
        $_SESSION['oauth_state'] = $state;

        $authUrl = $this->ssoService->getAuthorizationUrl($state);
        header('Location: ' . $authUrl);
        exit;
    }

    public function callback(): void
    {
        $code = $_GET['code'] ?? null;
        $state = $_GET['state'] ?? null;
        $error = $_GET['error'] ?? null;

        if ($error !== null) {
            $_SESSION['flash_error'] = 'SSO authentication failed: ' . htmlspecialchars($error);
            header('Location: /auth/login');
            exit;
        }

        if ($code === null) {
            $_SESSION['flash_error'] = 'No authorization code received.';
            header('Location: /auth/login');
            exit;
        }

        if ($state === null || !isset($_SESSION['oauth_state']) || !hash_equals($_SESSION['oauth_state'], $state)) {
            $_SESSION['flash_error'] = 'Invalid state parameter. Possible CSRF attack.';
            header('Location: /auth/login');
            exit;
        }

        unset($_SESSION['oauth_state']);

        try {
            $tokenData = $this->ssoService->exchangeCode($code);

            if (!isset($tokenData['access_token'])) {
                throw new \RuntimeException('No access token in SSO response');
            }

            $userInfo = $this->ssoService->getUserInfo($tokenData['access_token']);

            if (empty($userInfo['sub']) && empty($userInfo['id'])) {
                throw new \RuntimeException('Invalid user info from SSO');
            }

            $userModel = new User();
            $localUser = $userModel->createOrUpdate([
                'sso_id'   => $userInfo['sub'] ?? $userInfo['id'],
                'email'    => $userInfo['email'] ?? '',
                'name'     => $userInfo['name'] ?? $userInfo['preferred_username'] ?? '',
                'username' => $userInfo['preferred_username'] ?? $userInfo['username'] ?? '',
                'avatar'   => $userInfo['picture'] ?? null,
            ]);

            session_regenerate_id(true);

            $_SESSION['user'] = $localUser;
            $_SESSION['access_token'] = $tokenData['access_token'];
            $_SESSION['refresh_token'] = $tokenData['refresh_token'] ?? null;
            $_SESSION['token_expires'] = time() + ($tokenData['expires_in'] ?? 3600);

            header('Location: /');
            exit;
        } catch (\Throwable $e) {
            error_log('SSO callback error: ' . $e->getMessage());
            $_SESSION['flash_error'] = 'Authentication failed. Please try again.';
            header('Location: /auth/login');
            exit;
        }
    }

    public function logout(): void
    {
        $accessToken = $_SESSION['access_token'] ?? null;

        if ($accessToken !== null) {
            try {
                $this->ssoService->revokeToken($accessToken);
            } catch (\Throwable $e) {
                error_log('Token revocation failed: ' . $e->getMessage());
            }
        }

        $_SESSION = [];

        if (ini_get('session.use_cookies')) {
            $params = session_get_cookie_params();
            setcookie(
                session_name(),
                '',
                time() - 42000,
                $params['path'],
                $params['domain'],
                $params['secure'],
                $params['httponly']
            );
        }

        session_destroy();

        $logoutUrl = $this->config['sso']['server_url'] . '/logout?' . http_build_query([
            'client_id'                => $this->config['sso']['client_id'],
            'post_logout_redirect_uri' => $this->config['sso']['logout_uri'],
        ]);

        header('Location: ' . $logoutUrl);
        exit;
    }
}
