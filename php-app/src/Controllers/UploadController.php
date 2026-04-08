<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Services\UploadService;

class UploadController
{
    private array $config;
    private UploadService $uploadService;

    public function __construct(array $config)
    {
        $this->config = $config;
        $this->uploadService = new UploadService($config);
    }

    public function index(): void
    {
        $user = AuthMiddleware::getUser();

        $data = [
            'user'              => $user,
            'config'            => $this->config,
            'maxSize'           => $this->config['upload']['max_size'],
            'allowedExtensions' => $this->config['upload']['allowed_extensions'],
            'title'             => 'Upload Document',
        ];

        $this->render('upload/index', $data);
    }

    public function store(): void
    {
        $user = AuthMiddleware::getUser();

        if (!isset($_FILES['document']) || $_FILES['document']['error'] === UPLOAD_ERR_NO_FILE) {
            $_SESSION['flash_error'] = 'No file was uploaded.';
            header('Location: /upload');
            exit;
        }

        $file = $_FILES['document'];

        if ($file['error'] !== UPLOAD_ERR_OK) {
            $_SESSION['flash_error'] = $this->getUploadErrorMessage($file['error']);
            header('Location: /upload');
            exit;
        }

        try {
            $this->uploadService->validateFile($file);

            $result = $this->uploadService->uploadFile($file, (int) $user['id']);

            $_SESSION['flash_success'] = 'File uploaded successfully.';
            $_SESSION['last_upload'] = $result;

            if (isset($result['upload_id'])) {
                header('Location: /jobs?upload_id=' . urlencode((string) $result['upload_id']));
            } else {
                header('Location: /jobs');
            }
            exit;
        } catch (\InvalidArgumentException $e) {
            $_SESSION['flash_error'] = $e->getMessage();
            header('Location: /upload');
            exit;
        } catch (\RuntimeException $e) {
            error_log('Upload failed: ' . $e->getMessage());
            $_SESSION['flash_error'] = 'Upload failed. Please try again.';
            header('Location: /upload');
            exit;
        }
    }

    private function getUploadErrorMessage(int $code): string
    {
        return match ($code) {
            UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE => 'File is too large.',
            UPLOAD_ERR_PARTIAL    => 'File was only partially uploaded.',
            UPLOAD_ERR_NO_TMP_DIR => 'Server configuration error: missing temp directory.',
            UPLOAD_ERR_CANT_WRITE => 'Failed to write file to disk.',
            UPLOAD_ERR_EXTENSION  => 'File upload stopped by a PHP extension.',
            default               => 'An unknown upload error occurred.',
        };
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
            $title = $title ?? 'Upload';
            require $layout;
        } else {
            echo $pageContent;
        }
    }
}
