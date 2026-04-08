<?php

declare(strict_types=1);

namespace App\Models;

use App\Config\Database;
use PDO;

class Job
{
    private PDO $db;

    public function __construct()
    {
        $this->db = Database::getInstance();
    }

    /**
     * @return array{id: int, external_id: ?string, upload_id: int, user_id: int, status: string}|null
     */
    public function findById(int $id): ?array
    {
        $stmt = $this->db->prepare(
            'SELECT id, external_id, upload_id, user_id, status, language, engine, 
                    created_at, updated_at, completed_at 
             FROM ocr_jobs 
             WHERE id = :id 
             LIMIT 1'
        );
        $stmt->execute(['id' => $id]);

        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result !== false ? $result : null;
    }

    /**
     * @return array<int, array{id: int, external_id: ?string, upload_id: int, status: string}>
     */
    public function findByUserId(int $userId, int $limit = 20, int $offset = 0): array
    {
        $stmt = $this->db->prepare(
            'SELECT id, external_id, upload_id, user_id, status, language, engine, 
                    created_at, updated_at, completed_at 
             FROM ocr_jobs 
             WHERE user_id = :user_id 
             ORDER BY created_at DESC 
             LIMIT :limit OFFSET :offset'
        );
        $stmt->bindValue('user_id', $userId, PDO::PARAM_INT);
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue('offset', $offset, PDO::PARAM_INT);
        $stmt->execute();

        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    /**
     * @return array{total: int, pending: int, processing: int, completed: int, failed: int, cancelled: int}
     */
    public function getStats(int $userId): array
    {
        $stmt = $this->db->prepare(
            'SELECT 
                COUNT(*) as total,
                COUNT(*) FILTER (WHERE status = \'pending\') as pending,
                COUNT(*) FILTER (WHERE status = \'processing\') as processing,
                COUNT(*) FILTER (WHERE status = \'completed\') as completed,
                COUNT(*) FILTER (WHERE status = \'failed\') as failed,
                COUNT(*) FILTER (WHERE status = \'cancelled\') as cancelled
             FROM ocr_jobs 
             WHERE user_id = :user_id'
        );
        $stmt->execute(['user_id' => $userId]);

        $result = $stmt->fetch(PDO::FETCH_ASSOC);

        return [
            'total'      => (int) ($result['total'] ?? 0),
            'pending'    => (int) ($result['pending'] ?? 0),
            'processing' => (int) ($result['processing'] ?? 0),
            'completed'  => (int) ($result['completed'] ?? 0),
            'failed'     => (int) ($result['failed'] ?? 0),
            'cancelled'  => (int) ($result['cancelled'] ?? 0),
        ];
    }

    /**
     * @return array{id: int, external_id: ?string, upload_id: int, user_id: int, status: string}
     */
    public function create(array $data): array
    {
        $stmt = $this->db->prepare(
            'INSERT INTO ocr_jobs (external_id, upload_id, user_id, status, language, engine, created_at, updated_at) 
             VALUES (:external_id, :upload_id, :user_id, :status, :language, :engine, NOW(), NOW()) 
             RETURNING id, external_id, upload_id, user_id, status, language, engine, created_at, updated_at'
        );

        $stmt->execute([
            'external_id' => $data['external_id'] ?? null,
            'upload_id'   => $data['upload_id'],
            'user_id'     => $data['user_id'],
            'status'      => $data['status'] ?? 'pending',
            'language'    => $data['language'] ?? 'eng',
            'engine'      => $data['engine'] ?? 'tesseract',
        ]);

        return $stmt->fetch(PDO::FETCH_ASSOC);
    }
}
