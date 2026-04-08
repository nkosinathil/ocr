<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Models\Job;

class DashboardController
{
    private array $config;

    public function __construct(array $config)
    {
        $this->config = $config;
    }

    public function index(): void
    {
        $user = AuthMiddleware::getUser();
        $jobModel = new Job();

        $stats = $jobModel->getStats((int) $user['id']);
        $recentJobs = $jobModel->findByUserId((int) $user['id'], 10, 0);

        $data = [
            'user'       => $user,
            'stats'      => $stats,
            'recentJobs' => $recentJobs,
            'config'     => $this->config,
        ];

        $this->render('dashboard/index', $data);
    }

    private function render(string $view, array $data = []): void
    {
        extract($data);
        $content = BASE_PATH . '/views/' . $view . '.php';
        $layout = BASE_PATH . '/views/layouts/main.php';

        if (!file_exists($content)) {
            http_response_code(500);
            echo 'View not found: ' . htmlspecialchars($view);
            return;
        }

        ob_start();
        require $content;
        $pageContent = ob_get_clean();

        if (file_exists($layout)) {
            $title = $title ?? 'Dashboard';
            require $layout;
        } else {
            echo $pageContent;
        }
    }
}
