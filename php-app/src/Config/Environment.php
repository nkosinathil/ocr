<?php
declare(strict_types=1);

namespace MxaOcr\Config;

use Dotenv\Dotenv;

/**
 * Environment Configuration Manager
 * 
 * Loads and manages environment variables from .env file.
 * This is specific to the MXA OCR product only.
 */
class Environment
{
    private static ?Environment $instance = null;
    private array $config = [];
    
    private function __construct()
    {
        $this->load();
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
     * Load environment variables from .env file
     */
    private function load(): void
    {
        $basePath = dirname(__DIR__, 2);
        
        // Load .env file if it exists
        if (file_exists($basePath . '/.env')) {
            $dotenv = Dotenv::createImmutable($basePath);
            $dotenv->load();
        }
        
        // Cache commonly used values
        $this->config = [
            'app' => [
                'name' => $this->get('APP_NAME', 'MXA OCR'),
                'env' => $this->get('APP_ENV', 'production'),
                'debug' => $this->getBool('APP_DEBUG', false),
                'url' => $this->get('APP_URL', 'https://ocr.gismartanalytics.com'),
                'timezone' => $this->get('APP_TIMEZONE', 'UTC'),
                'key' => $this->get('APP_KEY', ''),
            ],
            'database' => [
                'host' => $this->get('DB_HOST', '192.168.1.66'),
                'port' => $this->getInt('DB_PORT', 5432),
                'database' => $this->get('DB_DATABASE', 'mxa_ocr'),
                'username' => $this->get('DB_USERNAME', 'mxa_ocr_user'),
                'password' => $this->get('DB_PASSWORD', ''),
                'charset' => $this->get('DB_CHARSET', 'utf8'),
            ],
            'keycloak' => [
                'url' => $this->get('KEYCLOAK_URL', 'http://192.168.1.59:8080'),
                'realm' => $this->get('KEYCLOAK_REALM', 'master'),
                'client_id' => $this->get('KEYCLOAK_CLIENT_ID', 'mxa-ocr-web'),
                'client_secret' => $this->get('KEYCLOAK_CLIENT_SECRET', ''),
                'redirect_uri' => $this->get('KEYCLOAK_REDIRECT_URI', ''),
            ],
            'python_api' => [
                'url' => $this->get('PYTHON_API_URL', 'http://192.168.1.90:8100'),
                'timeout' => $this->getInt('PYTHON_API_TIMEOUT', 30),
                'api_key' => $this->get('PYTHON_API_KEY', ''),
            ],
            'minio' => [
                'endpoint' => $this->get('MINIO_ENDPOINT', '192.168.1.90:9000'),
                'access_key' => $this->get('MINIO_ACCESS_KEY', ''),
                'secret_key' => $this->get('MINIO_SECRET_KEY', ''),
                'bucket_input' => $this->get('MINIO_BUCKET_INPUT', 'mxa-ocr-input'),
                'bucket_output' => $this->get('MINIO_BUCKET_OUTPUT', 'mxa-ocr-output'),
                'use_ssl' => $this->getBool('MINIO_USE_SSL', false),
                'region' => $this->get('MINIO_REGION', 'us-east-1'),
            ],
            'session' => [
                'lifetime' => $this->getInt('SESSION_LIFETIME', 1800),
                'driver' => $this->get('SESSION_DRIVER', 'file'),
                'path' => $this->get('SESSION_PATH', '../storage/sessions'),
                'cookie_name' => $this->get('SESSION_COOKIE_NAME', 'mxa_ocr_session'),
                'cookie_secure' => $this->getBool('SESSION_COOKIE_SECURE', true),
                'cookie_httponly' => $this->getBool('SESSION_COOKIE_HTTPONLY', true),
                'cookie_samesite' => $this->get('SESSION_COOKIE_SAMESITE', 'Strict'),
            ],
            'upload' => [
                'max_size' => $this->getInt('UPLOAD_MAX_SIZE', 52428800), // 50MB
                'allowed_types' => explode(',', $this->get('UPLOAD_ALLOWED_TYPES', 'application/pdf')),
                'temp_dir' => $this->get('UPLOAD_TEMP_DIR', '../storage/uploads'),
            ],
            'logging' => [
                'level' => $this->get('LOG_LEVEL', 'info'),
                'path' => $this->get('LOG_PATH', '../storage/logs/app.log'),
                'max_files' => $this->getInt('LOG_MAX_FILES', 30),
            ],
            'security' => [
                'csrf_token_name' => $this->get('CSRF_TOKEN_NAME', 'mxa_ocr_csrf_token'),
                'password_pepper' => $this->get('PASSWORD_PEPPER', ''),
            ],
            'features' => [
                'registration_enabled' => $this->getBool('FEATURE_REGISTRATION_ENABLED', false),
                'batch_upload' => $this->getBool('FEATURE_BATCH_UPLOAD', true),
                'api_access' => $this->getBool('FEATURE_API_ACCESS', false),
            ],
            'rate_limit' => [
                'enabled' => $this->getBool('RATE_LIMIT_ENABLED', true),
                'max_requests' => $this->getInt('RATE_LIMIT_MAX_REQUESTS', 100),
                'window' => $this->getInt('RATE_LIMIT_WINDOW', 3600),
            ],
        ];
    }
    
    /**
     * Get environment variable
     */
    private function get(string $key, string $default = ''): string
    {
        return $_ENV[$key] ?? getenv($key) ?: $default;
    }
    
    /**
     * Get integer environment variable
     */
    private function getInt(string $key, int $default = 0): int
    {
        $value = $this->get($key, (string)$default);
        return (int)$value;
    }
    
    /**
     * Get boolean environment variable
     */
    private function getBool(string $key, bool $default = false): bool
    {
        $value = strtolower($this->get($key, $default ? 'true' : 'false'));
        return in_array($value, ['true', '1', 'yes', 'on'], true);
    }
    
    /**
     * Get configuration value
     */
    public function getConfig(string $key, mixed $default = null): mixed
    {
        $keys = explode('.', $key);
        $value = $this->config;
        
        foreach ($keys as $k) {
            if (!isset($value[$k])) {
                return $default;
            }
            $value = $value[$k];
        }
        
        return $value;
    }
    
    /**
     * Get all configuration
     */
    public function getAllConfig(): array
    {
        return $this->config;
    }
    
    /**
     * Check if application is in debug mode
     */
    public function isDebug(): bool
    {
        return $this->getConfig('app.debug', false);
    }
    
    /**
     * Check if application is in production
     */
    public function isProduction(): bool
    {
        return $this->getConfig('app.env') === 'production';
    }
}
