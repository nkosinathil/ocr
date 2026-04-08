<?php

declare(strict_types=1);

define('BASE_PATH', dirname(__DIR__));

require_once BASE_PATH . '/vendor/autoload.php';

$config = require BASE_PATH . '/config/app.php';

session_start();

$requestUri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$requestUri = rtrim($requestUri, '/') ?: '/';
$method = $_SERVER['REQUEST_METHOD'];

$publicRoutes = ['/auth/login', '/auth/callback'];

$isPublicRoute = in_array($requestUri, $publicRoutes, true);

if (!$isPublicRoute && $requestUri !== '/') {
    \App\Middleware\AuthMiddleware::requireAuth();
}

if ($requestUri === '/' && !\App\Middleware\AuthMiddleware::check()) {
    header('Location: /auth/login');
    exit;
}

try {
    match (true) {
        $requestUri === '/' => (new \App\Controllers\DashboardController($config))->index(),

        $requestUri === '/auth/login' => (new \App\Controllers\AuthController($config))->login(),
        $requestUri === '/auth/callback' => (new \App\Controllers\AuthController($config))->callback(),
        $requestUri === '/auth/logout' => (new \App\Controllers\AuthController($config))->logout(),

        $requestUri === '/upload' && $method === 'GET' => (new \App\Controllers\UploadController($config))->index(),
        $requestUri === '/upload' && $method === 'POST' => (new \App\Controllers\UploadController($config))->store(),

        $requestUri === '/jobs' => (new \App\Controllers\JobController($config))->index(),
        preg_match('#^/jobs/([a-f0-9\-]+)/status$#', $requestUri, $m) === 1
            => (new \App\Controllers\JobController($config))->status($m[1]),
        preg_match('#^/jobs/([a-f0-9\-]+)/cancel$#', $requestUri, $m) === 1 && $method === 'POST'
            => (new \App\Controllers\JobController($config))->cancel($m[1]),
        $requestUri === '/jobs/create' && $method === 'POST'
            => (new \App\Controllers\JobController($config))->create(),
        preg_match('#^/jobs/([a-f0-9\-]+)$#', $requestUri, $m) === 1
            => (new \App\Controllers\JobController($config))->show($m[1]),

        preg_match('#^/results/([a-f0-9\-]+)$#', $requestUri, $m) === 1
            => (new \App\Controllers\ResultController($config))->show($m[1]),
        preg_match('#^/results/([a-f0-9\-]+)/download$#', $requestUri, $m) === 1
            => (new \App\Controllers\ResultController($config))->download($m[1]),

        str_starts_with($requestUri, '/api/') => handleApiProxy($requestUri, $config),

        default => sendNotFound(),
    };
} catch (\Throwable $e) {
    handleError($e, $config);
}

function handleApiProxy(string $uri, array $config): void
{
    $apiBase = rtrim($config['api']['base_url'], '/');
    $apiPath = substr($uri, 4); // Strip "/api"
    $targetUrl = $apiBase . $apiPath;

    if (!empty($_SERVER['QUERY_STRING'])) {
        $targetUrl .= '?' . $_SERVER['QUERY_STRING'];
    }

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $targetUrl,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT        => $config['api']['timeout'],
        CURLOPT_CUSTOMREQUEST  => $_SERVER['REQUEST_METHOD'],
        CURLOPT_HTTPHEADER     => [
            'Content-Type: application/json',
            'Accept: application/json',
        ],
    ]);

    $input = file_get_contents('php://input');
    if ($input !== false && $input !== '') {
        curl_setopt($ch, CURLOPT_POSTFIELDS, $input);
    }

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);

    if ($response === false) {
        http_response_code(502);
        header('Content-Type: application/json');
        echo json_encode(['error' => 'Backend unavailable', 'detail' => $error]);
        return;
    }

    http_response_code($httpCode);
    header('Content-Type: application/json');
    echo $response;
}

function sendNotFound(): void
{
    http_response_code(404);
    echo '<!DOCTYPE html><html><head><title>404 Not Found</title></head>';
    echo '<body><h1>404 - Page Not Found</h1><p>The requested page does not exist.</p>';
    echo '<a href="/">Return to Dashboard</a></body></html>';
}

function handleError(\Throwable $e, array $config): void
{
    http_response_code(500);

    if ($config['app']['debug']) {
        echo '<h1>Error</h1>';
        echo '<p>' . htmlspecialchars($e->getMessage()) . '</p>';
        echo '<pre>' . htmlspecialchars($e->getTraceAsString()) . '</pre>';
    } else {
        echo '<!DOCTYPE html><html><head><title>Server Error</title></head>';
        echo '<body><h1>500 - Internal Server Error</h1>';
        echo '<p>Something went wrong. Please try again later.</p></body></html>';
    }

    error_log(sprintf('[%s] %s in %s:%d', date('Y-m-d H:i:s'), $e->getMessage(), $e->getFile(), $e->getLine()));
}
