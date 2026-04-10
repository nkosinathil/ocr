<?php
declare(strict_types=1);

namespace MxaOcr\Repositories;

use MxaOcr\Config\Database;
use MxaOcr\Models\Job;

/**
 * Job Repository
 * 
 * Data access layer for jobs table.
 */
class JobRepository
{
    /**
     * Find job by ID
     */
    public function findById(string $id): ?Job
    {
        $sql = "SELECT * FROM jobs WHERE id = :id LIMIT 1";
        $result = Database::queryOne($sql, ['id' => $id]);
        
        return $result ? new Job($result) : null;
    }
    
    /**
     * Find jobs by user ID
     */
    public function findByUserId(string $userId, int $limit = 50, int $offset = 0): array
    {
        $sql = "SELECT * FROM jobs 
                WHERE user_id = :user_id 
                ORDER BY submitted_at DESC 
                LIMIT :limit OFFSET :offset";
        
        $results = Database::query($sql, [
            'user_id' => $userId,
            'limit' => $limit,
            'offset' => $offset,
        ]);
        
        return array_map(fn($row) => new Job($row), $results);
    }
    
    /**
     * Find jobs by status
     */
    public function findByStatus(string $status, int $limit = 50): array
    {
        $sql = "SELECT * FROM jobs 
                WHERE status = :status 
                ORDER BY priority DESC, submitted_at ASC 
                LIMIT :limit";
        
        $results = Database::query($sql, [
            'status' => $status,
            'limit' => $limit,
        ]);
        
        return array_map(fn($row) => new Job($row), $results);
    }
    
    /**
     * Create new job
     */
    public function create(array $data): Job
    {
        $sql = "INSERT INTO jobs (
                    user_id, status, priority, original_filename, file_size, 
                    file_type, minio_input_path, metadata
                ) VALUES (
                    :user_id, :status, :priority, :original_filename, :file_size,
                    :file_type, :minio_input_path, :metadata
                ) RETURNING *";
        
        $params = [
            'user_id' => $data['user_id'],
            'status' => $data['status'] ?? 'pending',
            'priority' => $data['priority'] ?? 5,
            'original_filename' => $data['original_filename'],
            'file_size' => $data['file_size'],
            'file_type' => $data['file_type'],
            'minio_input_path' => $data['minio_input_path'],
            'metadata' => json_encode($data['metadata'] ?? []),
        ];
        
        $result = Database::queryOne($sql, $params);
        return new Job($result);
    }
    
    /**
     * Update job status
     */
    public function updateStatus(string $id, string $status, ?string $errorMessage = null): bool
    {
        $params = ['id' => $id, 'status' => $status];
        $fields = ['status = :status'];
        
        if ($status === 'processing' && !$this->findById($id)->startedAt) {
            $fields[] = 'started_at = CURRENT_TIMESTAMP';
        }
        
        if (in_array($status, ['completed', 'failed', 'cancelled'])) {
            $fields[] = 'completed_at = CURRENT_TIMESTAMP';
        }
        
        if ($errorMessage !== null) {
            $fields[] = 'error_message = :error_message';
            $params['error_message'] = $errorMessage;
        }
        
        $sql = "UPDATE jobs SET " . implode(', ', $fields) . " WHERE id = :id";
        return Database::execute($sql, $params) > 0;
    }
    
    /**
     * Update job with output path
     */
    public function updateOutputPath(string $id, string $outputPath): bool
    {
        $sql = "UPDATE jobs SET minio_output_path = :output_path WHERE id = :id";
        return Database::execute($sql, [
            'id' => $id,
            'output_path' => $outputPath,
        ]) > 0;
    }
    
    /**
     * Delete job
     */
    public function delete(string $id): bool
    {
        $sql = "DELETE FROM jobs WHERE id = :id";
        return Database::execute($sql, ['id' => $id]) > 0;
    }
    
    /**
     * Get job count by user and status
     */
    public function countByUserAndStatus(string $userId, string $status): int
    {
        $sql = "SELECT COUNT(*) as count FROM jobs 
                WHERE user_id = :user_id AND status = :status";
        
        $result = Database::queryOne($sql, [
            'user_id' => $userId,
            'status' => $status,
        ]);
        
        return (int)$result['count'];
    }
    
    /**
     * Get total count for user
     */
    public function countByUser(string $userId): int
    {
        $sql = "SELECT COUNT(*) as count FROM jobs WHERE user_id = :user_id";
        $result = Database::queryOne($sql, ['user_id' => $userId]);
        return (int)$result['count'];
    }
}
