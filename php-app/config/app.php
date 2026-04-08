<?php

declare(strict_types=1);

/**
 * Application configuration loader.
 * Parses .env file and returns a structured configuration array.
 */

(function (): void {
    $envPath = dirname(__DIR__) . '/.env';

    if (!file_exists($envPath)) {
        throw new RuntimeException('.env file not found at: ' . $envPath);
    }

    $lines = file($envPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);

    if ($lines === false) {
        throw new RuntimeException('Failed to read .env file');
    }

    foreach ($lines as $line) {
        $line = trim($line);

        if ($line === '' || str_starts_with($line, '#')) {
            continue;
        }

        $eqPos = strpos($line, '=');
        if ($eqPos === false) {
            continue;
        }

        $key = trim(substr($line, 0, $eqPos));
        $value = trim(substr($line, $eqPos + 1));

        if (!array_key_exists($key, $_ENV)) {
            $_ENV[$key] = $value;
            putenv("{$key}={$value}");
        }
    }
})();

function env(string $key, mixed $default = null): mixed
{
    return $_ENV[$key] ?? getenv($key) ?: $default;
}

return [
    'app' => [
        'name'   => env('APP_NAME', 'OCR Platform'),
        'env'    => env('APP_ENV', 'production'),
        'debug'  => filter_var(env('APP_DEBUG', false), FILTER_VALIDATE_BOOLEAN),
        'url'    => env('APP_URL', 'http://localhost'),
        'secret' => env('APP_SECRET', ''),
    ],

    'sso' => [
        'server_url'    => env('SSO_SERVER_URL', ''),
        'client_id'     => env('SSO_CLIENT_ID', ''),
        'client_secret' => env('SSO_CLIENT_SECRET', ''),
        'redirect_uri'  => env('SSO_REDIRECT_URI', ''),
        'logout_uri'    => env('SSO_LOGOUT_URI', ''),
    ],

    'api' => [
        'base_url' => env('PYTHON_API_BASE_URL', 'http://127.0.0.1:8000'),
        'version'  => env('PYTHON_API_VERSION', 'v1'),
        'timeout'  => (int) env('PYTHON_API_TIMEOUT', 30),
    ],

    'database' => [
        'host'     => env('DB_HOST', '127.0.0.1'),
        'port'     => env('DB_PORT', '5432'),
        'name'     => env('DB_NAME', 'ocr_platform'),
        'user'     => env('DB_USER', 'ocr_app'),
        'password' => env('DB_PASSWORD', ''),
    ],

    'upload' => [
        'max_size'           => (int) env('MAX_UPLOAD_SIZE', 104857600),
        'allowed_extensions' => explode(',', env('ALLOWED_EXTENSIONS', 'pdf,jpg,jpeg,png,tiff,bmp,webp')),
    ],
];
