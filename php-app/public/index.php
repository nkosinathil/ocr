<?php
declare(strict_types=1);

/**
 * MXA OCR - Main Entry Point
 * 
 * This is the single entry point for all web requests.
 * All requests are routed through this file.
 */

// Start output buffering
ob_start();

// Set error reporting based on environment
ini_set('display_errors', '0');
ini_set('display_startup_errors', '0');
error_reporting(E_ALL);

// Define paths
define('BASE_PATH', dirname(__DIR__));
define('APP_PATH', BASE_PATH . '/src');
define('STORAGE_PATH', BASE_PATH . '/storage');

// Load Composer autoloader
require_once BASE_PATH . '/vendor/autoload.php';

use MxaOcr\Config\Environment;
use MxaOcr\Config\Database;

// Initialize environment
$env = Environment::getInstance();

// Configure error display based on debug mode
if ($env->isDebug()) {
    ini_set('display_errors', '1');
    ini_set('display_startup_errors', '1');
}

// Set timezone
date_default_timezone_set($env->getConfig('app.timezone', 'UTC'));

// Start session
session_start([
    'name' => $env->getConfig('session.cookie_name'),
    'cookie_lifetime' => $env->getConfig('session.lifetime'),
    'cookie_secure' => $env->getConfig('session.cookie_secure'),
    'cookie_httponly' => $env->getConfig('session.cookie_httponly'),
    'cookie_samesite' => $env->getConfig('session.cookie_samesite'),
    'use_strict_mode' => true,
    'use_only_cookies' => true,
]);

// Simple router
$requestUri = $_SERVER['REQUEST_URI'];
$requestMethod = $_SERVER['REQUEST_METHOD'];

// Remove query string
$path = parse_url($requestUri, PHP_URL_PATH);

// Remove leading slash
$path = ltrim($path, '/');

// Basic routing
switch ($path) {
    case '':
    case 'dashboard':
        // Check if user is logged in
        if (!isset($_SESSION['user_id'])) {
            header('Location: /auth/login');
            exit;
        }
        require APP_PATH . '/Views/dashboard.php';
        break;
        
    case 'auth/login':
        require APP_PATH . '/Views/auth/login.php';
        break;
        
    case 'auth/callback':
        // Handle OAuth callback
        if ($requestMethod === 'GET' && isset($_GET['code'])) {
            require APP_PATH . '/Views/auth/callback.php';
        } else {
            http_response_code(400);
            echo 'Invalid callback request';
        }
        break;
        
    case 'auth/logout':
        // Clear session
        $_SESSION = [];
        session_destroy();
        header('Location: /auth/login');
        exit;
        
    case 'upload':
        if (!isset($_SESSION['user_id'])) {
            header('Location: /auth/login');
            exit;
        }
        require APP_PATH . '/Views/upload.php';
        break;
        
    case 'jobs':
        if (!isset($_SESSION['user_id'])) {
            header('Location: /auth/login');
            exit;
        }
        require APP_PATH . '/Views/jobs.php';
        break;
        
    case 'api/health':
        header('Content-Type: application/json');
        echo json_encode([
            'status' => 'healthy',
            'application' => 'MXA OCR',
            'timestamp' => date('c'),
        ]);
        break;
        
    default:
        // Static file handling is done by Apache
        // If we get here, it's a 404
        http_response_code(404);
        echo '<h1>404 - Page Not Found</h1>';
        echo '<p>The page you are looking for does not exist.</p>';
        echo '<a href="/">Return to Dashboard</a>';
        break;
}

// Flush output
ob_end_flush();
