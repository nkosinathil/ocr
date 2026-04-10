<?php
declare(strict_types=1);

namespace MxaOcr\Repositories;

use MxaOcr\Config\Database;

/**
 * Audit Repository
 * 
 * Data access layer for audit_logs table.
 */
class AuditRepository
{
    /**
     * Log an audit event
     */
    public function log(array $data): bool
    {
        $sql = "INSERT INTO audit_logs (
                    user_id, action, resource_type, resource_id,
                    ip_address, user_agent, details
                ) VALUES (
                    :user_id, :action, :resource_type, :resource_id,
                    :ip_address, :user_agent, :details
                )";
        
        $params = [
            'user_id' => $data['user_id'] ?? null,
            'action' => $data['action'],
            'resource_type' => $data['resource_type'] ?? null,
            'resource_id' => $data['resource_id'] ?? null,
            'ip_address' => $data['ip_address'] ?? $this->getClientIp(),
            'user_agent' => $data['user_agent'] ?? ($_SERVER['HTTP_USER_AGENT'] ?? null),
            'details' => json_encode($data['details'] ?? []),
        ];
        
        return Database::execute($sql, $params) > 0;
    }
    
    /**
     * Get audit logs for a user
     */
    public function findByUser(string $userId, int $limit = 100, int $offset = 0): array
    {
        $sql = "SELECT * FROM audit_logs 
                WHERE user_id = :user_id 
                ORDER BY created_at DESC 
                LIMIT :limit OFFSET :offset";
        
        return Database::query($sql, [
            'user_id' => $userId,
            'limit' => $limit,
            'offset' => $offset,
        ]);
    }
    
    /**
     * Get audit logs for a resource
     */
    public function findByResource(string $resourceType, string $resourceId, int $limit = 50): array
    {
        $sql = "SELECT * FROM audit_logs 
                WHERE resource_type = :resource_type AND resource_id = :resource_id
                ORDER BY created_at DESC 
                LIMIT :limit";
        
        return Database::query($sql, [
            'resource_type' => $resourceType,
            'resource_id' => $resourceId,
            'limit' => $limit,
        ]);
    }
    
    /**
     * Get recent audit logs
     */
    public function findRecent(int $limit = 100): array
    {
        $sql = "SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT :limit";
        return Database::query($sql, ['limit' => $limit]);
    }
    
    /**
     * Get client IP address
     */
    private function getClientIp(): ?string
    {
        if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
            $ips = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR']);
            return trim($ips[0]);
        }
        
        if (!empty($_SERVER['HTTP_X_REAL_IP'])) {
            return $_SERVER['HTTP_X_REAL_IP'];
        }
        
        return $_SERVER['REMOTE_ADDR'] ?? null;
    }
}
