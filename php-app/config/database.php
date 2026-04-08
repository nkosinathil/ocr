<?php

declare(strict_types=1);

namespace App\Config;

use PDO;
use PDOException;
use RuntimeException;

class Database
{
    private static ?PDO $instance = null;

    private function __construct()
    {
    }

    private function __clone()
    {
    }

    public static function getInstance(): PDO
    {
        if (self::$instance === null) {
            $config = self::loadConfig();

            $dsn = sprintf(
                'pgsql:host=%s;port=%s;dbname=%s',
                $config['host'],
                $config['port'],
                $config['name']
            );

            try {
                self::$instance = new PDO($dsn, $config['user'], $config['password'], [
                    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES   => false,
                    PDO::ATTR_STRINGIFY_FETCHES  => false,
                ]);
            } catch (PDOException $e) {
                throw new RuntimeException('Database connection failed: ' . $e->getMessage(), (int) $e->getCode(), $e);
            }
        }

        return self::$instance;
    }

    private static function loadConfig(): array
    {
        $configPath = defined('BASE_PATH')
            ? BASE_PATH . '/config/app.php'
            : dirname(__DIR__) . '/app.php';

        if (!file_exists($configPath)) {
            $configPath = dirname(__DIR__) . '/config/app.php';
        }

        $appConfig = require $configPath;

        return $appConfig['database'] ?? throw new RuntimeException('Database configuration not found');
    }

    public static function reset(): void
    {
        self::$instance = null;
    }
}
