<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Job as JobModel;

class JobService
{
    private ApiService $api;
    private array $config;

    public function __construct(array $config)
    {
        $this->config = $config;
        $this->api = new ApiService($config['api']);
    }

    public function createJob(string $uploadId, string $language = 'eng', string $engine = 'tesseract'): array
    {
        return $this->api->post('ocr/jobs', [
            'upload_id' => $uploadId,
            'language'  => $language,
            'engine'    => $engine,
        ]);
    }

    /**
     * @return array{id: int|string, status: string, progress?: int, created_at?: string, updated_at?: string}
     */
    public function getJobStatus(string $jobId): array
    {
        return $this->api->get('ocr/jobs/' . $jobId . '/status');
    }

    /**
     * @return array{text?: string, content?: string, pages?: array, confidence?: float}
     */
    public function getJobResult(string $jobId): array
    {
        return $this->api->get('ocr/jobs/' . $jobId . '/result');
    }

    /**
     * @return array{jobs: array, total: int, page: int, limit: int}
     */
    public function listJobs(string $userId, int $page = 1, int $limit = 20): array
    {
        try {
            $response = $this->api->get('ocr/jobs', [
                'user_id' => $userId,
                'page'    => $page,
                'limit'   => $limit,
            ]);

            return [
                'jobs'  => $response['jobs'] ?? $response['data'] ?? $response['items'] ?? [],
                'total' => $response['total'] ?? $response['count'] ?? 0,
                'page'  => $page,
                'limit' => $limit,
            ];
        } catch (\Throwable $e) {
            error_log('Failed to list jobs from API: ' . $e->getMessage());

            $jobModel = new JobModel();
            $offset = ($page - 1) * $limit;
            $jobs = $jobModel->findByUserId($userId, $limit, $offset);
            $stats = $jobModel->getStats($userId);

            return [
                'jobs'  => $jobs,
                'total' => (int) ($stats['total'] ?? 0),
                'page'  => $page,
                'limit' => $limit,
            ];
        }
    }

    /**
     * @return array{id: int|string, status: string}
     */
    public function cancelJob(string $jobId): array
    {
        return $this->api->delete('ocr/jobs/' . $jobId);
    }
}
