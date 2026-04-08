<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Services\JobService;

class ResultController
{
    private array $config;
    private JobService $jobService;

    public function __construct(array $config)
    {
        $this->config = $config;
        $this->jobService = new JobService($config);
    }

    public function show(int $id): void
    {
        $user = AuthMiddleware::getUser();

        try {
            $result = $this->jobService->getJobResult($id);

            if (empty($result)) {
                http_response_code(404);
                $_SESSION['flash_error'] = 'Results not found for this job.';
                header('Location: /jobs');
                exit;
            }

            $data = [
                'user'   => $user,
                'config' => $this->config,
                'result' => $result,
                'jobId'  => $id,
                'title'  => 'Results - Job #' . $id,
            ];

            $this->render('results/show', $data);
        } catch (\Throwable $e) {
            error_log('Result show error: ' . $e->getMessage());
            $_SESSION['flash_error'] = 'Failed to load results.';
            header('Location: /jobs/' . $id);
            exit;
        }
    }

    public function download(int $id): void
    {
        try {
            $result = $this->jobService->getJobResult($id);

            if (empty($result)) {
                http_response_code(404);
                $_SESSION['flash_error'] = 'Results not found.';
                header('Location: /jobs');
                exit;
            }

            $text = $result['text'] ?? $result['content'] ?? $result['extracted_text'] ?? '';
            $filename = 'ocr_result_job_' . $id . '.txt';

            header('Content-Type: text/plain; charset=utf-8');
            header('Content-Disposition: attachment; filename="' . $filename . '"');
            header('Content-Length: ' . strlen($text));
            header('Cache-Control: no-cache, no-store, must-revalidate');

            echo $text;
            exit;
        } catch (\Throwable $e) {
            error_log('Result download error: ' . $e->getMessage());
            $_SESSION['flash_error'] = 'Failed to download results.';
            header('Location: /results/' . $id);
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
            $title = $title ?? 'Results';
            require $layout;
        } else {
            echo $pageContent;
        }
    }
}
