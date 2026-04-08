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

    /**
     * @return array{id: int|string, status: string, upload_id: int|string, language: string, engine: string}
     */
    public function createJob(int $uploadId, string $language = 'eng', string $engine = 'tesseract'): array
    {
        $response = $this->api->post('ocr/jobs', [
            'upload_id' => $uploadId,
            'language'  => $language,
            'engine'    => $engine,
        ]);

        try {
            $jobModel = new JobModel();
            $jobModel->create([
                'external_id' => $response['id'] ?? $response['job_id'] ?? null,
                'upload_id'   => $uploadId,
                'user_id'     => $_SESSION['user']['id'] ?? null,
                'status'      => $response['status'] ?? 'pending',
                'language'    => $language,
                'engine'      => $engine,
            ]);
        } catch (\Throwable $e) {
            error_log('Failed to store job locally: ' . $e->getMessage());
        }

        return $response;
    }

    /**
     * @return array{id: int|string, status: string, progress?: int, created_at?: string, updated_at?: string}
     */
    public function getJobStatus(int $jobId): array
    {
        return $this->api->get('ocr/jobs/' . $jobId);
    }

    /**
     * @return array{text?: string, content?: string, pages?: array, confidence?: float}
     */
    public function getJobResult(int $jobId): array
    {
        return $this->api->get('ocr/jobs/' . $jobId . '/result');
    }

    /**
     * @return array{jobs: array, total: int, page: int, limit: int}
     */
    public function listJobs(int $userId, int $page = 1, int $limit = 20): array
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
    public function cancelJob(int $jobId): array
    {
        return $this->api->post('ocr/jobs/' . $jobId . '/cancel');
    }
}
