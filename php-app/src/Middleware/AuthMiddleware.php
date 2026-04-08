<?php

declare(strict_types=1);

namespace App\Middleware;

class AuthMiddleware
{
    public static function check(): bool
    {
        if (session_status() !== PHP_SESSION_ACTIVE) {
            return false;
        }

        if (empty($_SESSION['user']) || !is_array($_SESSION['user'])) {
            return false;
        }

        if (empty($_SESSION['user']['id'])) {
            return false;
        }

        if (isset($_SESSION['token_expires']) && $_SESSION['token_expires'] < time()) {
            return false;
        }

        return true;
    }

    /**
     * @return array{id: int, sso_id: string, email: string, name: string, username: string, avatar: ?string}
     */
    public static function getUser(): array
    {
        if (!self::check()) {
            self::requireAuth();
        }

        return $_SESSION['user'];
    }

    public static function requireAuth(): void
    {
        if (!self::check()) {
            $_SESSION['intended_url'] = $_SERVER['REQUEST_URI'] ?? '/';

            header('Location: /auth/login');
            exit;
        }
    }
}
