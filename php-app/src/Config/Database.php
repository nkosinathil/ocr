<?php
declare(strict_types=1);

namespace MxaOcr\Config;

use PDO;
use PDOException;

/**
 * Database Connection Manager
 * 
 * Manages PostgreSQL database connections for the MXA OCR product.
 * Uses PDO for secure database access with prepared statements.
 */
class Database
{
    private static ?PDO $connection = null;
    private static ?Database $instance = null;
    
    private function __construct()
    {
        // Private constructor to enforce singleton
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
     * Get database connection
     */
    public static function getConnection(): PDO
    {
        if (self::$connection === null) {
            self::$connection = self::createConnection();
        }
        return self::$connection;
    }
    
    /**
     * Create new database connection
     */
    private static function createConnection(): PDO
    {
        $env = Environment::getInstance();
        
        $host = $env->getConfig('database.host');
        $port = $env->getConfig('database.port');
        $database = $env->getConfig('database.database');
        $username = $env->getConfig('database.username');
        $password = $env->getConfig('database.password');
        $charset = $env->getConfig('database.charset');
        
        $dsn = sprintf(
            'pgsql:host=%s;port=%d;dbname=%s;options=\'--client_encoding=%s\'',
            $host,
            $port,
            $database,
            $charset
        );
        
        try {
            $pdo = new PDO($dsn, $username, $password, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
                PDO::ATTR_PERSISTENT => false,
            ]);
            
            // Set timezone
            $timezone = $env->getConfig('app.timezone', 'UTC');
            $pdo->exec("SET TIME ZONE '$timezone'");
            
            return $pdo;
        } catch (PDOException $e) {
            // Log error but don't expose database details
            error_log('Database connection failed: ' . $e->getMessage());
            throw new \RuntimeException('Database connection failed. Please check configuration.');
        }
    }
    
    /**
     * Close database connection
     */
    public static function close(): void
    {
        self::$connection = null;
    }
    
    /**
     * Begin transaction
     */
    public static function beginTransaction(): bool
    {
        return self::getConnection()->beginTransaction();
    }
    
    /**
     * Commit transaction
     */
    public static function commit(): bool
    {
        return self::getConnection()->commit();
    }
    
    /**
     * Rollback transaction
     */
    public static function rollBack(): bool
    {
        return self::getConnection()->rollBack();
    }
    
    /**
     * Execute query and return all results
     */
    public static function query(string $sql, array $params = []): array
    {
        $stmt = self::getConnection()->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }
    
    /**
     * Execute query and return single row
     */
    public static function queryOne(string $sql, array $params = []): ?array
    {
        $stmt = self::getConnection()->prepare($sql);
        $stmt->execute($params);
        $result = $stmt->fetch();
        return $result ?: null;
    }
    
    /**
     * Execute INSERT/UPDATE/DELETE and return affected rows
     */
    public static function execute(string $sql, array $params = []): int
    {
        $stmt = self::getConnection()->prepare($sql);
        $stmt->execute($params);
        return $stmt->rowCount();
    }
    
    /**
     * Execute INSERT and return last insert ID
     */
    public static function insert(string $sql, array $params = []): string
    {
        $stmt = self::getConnection()->prepare($sql);
        $stmt->execute($params);
        return self::getConnection()->lastInsertId();
    }
    
    /**
     * Check if connection is alive
     */
    public static function isConnected(): bool
    {
        if (self::$connection === null) {
            return false;
        }
        
        try {
            self::$connection->query('SELECT 1');
            return true;
        } catch (PDOException $e) {
            return false;
        }
    }
    
    /**
     * Ping database to keep connection alive
     */
    public static function ping(): bool
    {
        if (!self::isConnected()) {
            self::close();
            self::$connection = self::createConnection();
        }
        return self::isConnected();
    }
}
