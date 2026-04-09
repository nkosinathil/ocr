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

    public function findById(string $id): ?array
    {
        $stmt = $this->db->prepare(
            'SELECT j.id, j.upload_id, j.user_id, j.status, j.language, j.engine,
                    j.priority, j.celery_task_id, j.progress_percent, j.pages_processed,
                    j.pages_total, j.started_at, j.completed_at, j.error_message,
                    j.created_at, j.updated_at,
                    u.original_filename
             FROM ocr_jobs j
             LEFT JOIN uploads u ON j.upload_id = u.id
             WHERE j.id = :id
             LIMIT 1'
        );
        $stmt->execute(['id' => $id]);

        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result !== false ? $result : null;
    }

    public function findByUserId(string $userId, int $limit = 20, int $offset = 0): array
    {
        $stmt = $this->db->prepare(
            'SELECT j.id, j.upload_id, j.user_id, j.status, j.language, j.engine,
                    j.priority, j.progress_percent, j.pages_processed, j.pages_total,
                    j.started_at, j.completed_at, j.error_message,
                    j.created_at, j.updated_at,
                    u.original_filename
             FROM ocr_jobs j
             LEFT JOIN uploads u ON j.upload_id = u.id
             WHERE j.user_id = :user_id
             ORDER BY j.created_at DESC
             LIMIT :limit OFFSET :offset'
        );
        $stmt->bindValue('user_id', $userId);
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue('offset', $offset, PDO::PARAM_INT);
        $stmt->execute();

        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function getStats(string $userId): array
    {
        $stmt = $this->db->prepare(
            "SELECT
                COUNT(*) as total,
                COUNT(*) FILTER (WHERE status = 'pending') as pending,
                COUNT(*) FILTER (WHERE status = 'queued') as queued,
                COUNT(*) FILTER (WHERE status = 'processing') as processing,
                COUNT(*) FILTER (WHERE status = 'completed') as completed,
                COUNT(*) FILTER (WHERE status = 'failed') as failed,
                COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled
             FROM ocr_jobs
             WHERE user_id = :user_id"
        );
        $stmt->execute(['user_id' => $userId]);

        $result = $stmt->fetch(PDO::FETCH_ASSOC);

        return [
            'total'      => (int) ($result['total'] ?? 0),
            'pending'    => (int) ($result['pending'] ?? 0),
            'queued'     => (int) ($result['queued'] ?? 0),
            'processing' => (int) ($result['processing'] ?? 0),
            'completed'  => (int) ($result['completed'] ?? 0),
            'failed'     => (int) ($result['failed'] ?? 0),
            'cancelled'  => (int) ($result['cancelled'] ?? 0),
        ];
    }

    public function countByUserId(string $userId): int
    {
        $stmt = $this->db->prepare(
            'SELECT COUNT(*) as total FROM ocr_jobs WHERE user_id = :user_id'
        );
        $stmt->execute(['user_id' => $userId]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return (int) ($result['total'] ?? 0);
    }
}
