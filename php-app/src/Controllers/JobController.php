<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Services\JobService;
use App\Models\Job;

class JobController
{
    private array $config;
    private JobService $jobService;

    public function __construct(array $config)
    {
        $this->config = $config;
        $this->jobService = new JobService($config);
    }

    public function index(): void
    {
        $user = AuthMiddleware::getUser();

        $page = max(1, (int) ($_GET['page'] ?? 1));
        $limit = 20;

        $result = $this->jobService->listJobs((int) $user['id'], $page, $limit);

        $data = [
            'user'       => $user,
            'config'     => $this->config,
            'jobs'       => $result['jobs'] ?? [],
            'total'      => $result['total'] ?? 0,
            'page'       => $page,
            'limit'      => $limit,
            'totalPages' => (int) ceil(($result['total'] ?? 0) / $limit),
            'title'      => 'OCR Jobs',
        ];

        $this->render('jobs/index', $data);
    }

    public function show(int $id): void
    {
        $user = AuthMiddleware::getUser();

        try {
            $job = $this->jobService->getJobStatus($id);

            if (empty($job)) {
                http_response_code(404);
                $_SESSION['flash_error'] = 'Job not found.';
                header('Location: /jobs');
                exit;
            }

            $data = [
                'user'   => $user,
                'config' => $this->config,
                'job'    => $job,
                'title'  => 'Job #' . $id,
            ];

            $this->render('jobs/show', $data);
        } catch (\Throwable $e) {
            error_log('Job show error: ' . $e->getMessage());
            $_SESSION['flash_error'] = 'Failed to load job details.';
            header('Location: /jobs');
            exit;
        }
    }

    public function create(): void
    {
        $user = AuthMiddleware::getUser();

        $uploadId = $_POST['upload_id'] ?? null;
        $language = $_POST['language'] ?? 'eng';
        $engine = $_POST['engine'] ?? 'tesseract';

        if ($uploadId === null) {
            $_SESSION['flash_error'] = 'Upload ID is required to create a job.';
            header('Location: /upload');
            exit;
        }

        try {
            $job = $this->jobService->createJob((int) $uploadId, $language, $engine);

            $_SESSION['flash_success'] = 'OCR job created successfully.';
            header('Location: /jobs/' . ($job['id'] ?? $job['job_id'] ?? ''));
            exit;
        } catch (\Throwable $e) {
            error_log('Job creation error: ' . $e->getMessage());
            $_SESSION['flash_error'] = 'Failed to create OCR job: ' . $e->getMessage();
            header('Location: /jobs');
            exit;
        }
    }

    public function status(int $id): void
    {
        header('Content-Type: application/json');

        try {
            $status = $this->jobService->getJobStatus($id);
            echo json_encode($status, JSON_THROW_ON_ERROR);
        } catch (\Throwable $e) {
            http_response_code(500);
            echo json_encode(['error' => 'Failed to fetch job status', 'detail' => $e->getMessage()]);
        }
    }

    public function cancel(int $id): void
    {
        try {
            $this->jobService->cancelJob($id);
            $_SESSION['flash_success'] = 'Job #' . $id . ' has been cancelled.';
        } catch (\Throwable $e) {
            error_log('Job cancel error: ' . $e->getMessage());
            $_SESSION['flash_error'] = 'Failed to cancel job.';
        }

        $isAjax = ($_SERVER['HTTP_X_REQUESTED_WITH'] ?? '') === 'XMLHttpRequest'
            || str_contains($_SERVER['HTTP_ACCEPT'] ?? '', 'application/json');

        if ($isAjax) {
            header('Content-Type: application/json');
            echo json_encode(['success' => !isset($_SESSION['flash_error']), 'redirect' => '/jobs/' . $id]);
        } else {
            header('Location: /jobs/' . $id);
            exit;
        }
    }

    private function render(string $view, array $data = []): void
    {
        extract($data);
        $content = BASE_PATH . '/views/' . $view . '.php';
        $layout = BASE_PATH . '/views/layouts/main.php';

        ob_start();
        if (file_exists($content)) {
            require $content;
        }
        $pageContent = ob_get_clean();

        if (file_exists($layout)) {
            $title = $title ?? 'Jobs';
            require $layout;
        } else {
            echo $pageContent;
        }
    }
}
