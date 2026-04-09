<?php

declare(strict_types=1);

namespace App\Services;

use InvalidArgumentException;
use RuntimeException;

class UploadService
{
    private ApiService $api;
    private array $config;

    private const MIME_TYPE_MAP = [
        'pdf'  => 'application/pdf',
        'jpg'  => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'png'  => 'image/png',
        'tiff' => 'image/tiff',
        'tif'  => 'image/tiff',
        'bmp'  => 'image/bmp',
        'webp' => 'image/webp',
    ];

    public function __construct(array $config)
    {
        $this->config = $config;
        $this->api = new ApiService($config['api']);
    }

    /**
     * @param array{tmp_name: string, name: string, type: string, size: int, error: int} $file
     * @return array{upload_id: int|string, filename: string, status: string}
     */
    public function uploadFile(array $file, string $userId): array
    {
        $this->validateFile($file);

        $tmpPath = $file['tmp_name'];
        $originalName = basename($file['name']);

        if (!is_uploaded_file($tmpPath)) {
            throw new RuntimeException('Invalid upload: file was not uploaded via HTTP POST');
        }

        try {
            $response = $this->api->postFile(
                'ocr/upload',
                $tmpPath,
                $originalName,
                ['user_id' => (string) $userId]
            );

            return [
                'upload_id' => $response['upload_id'] ?? $response['id'] ?? null,
                'filename'  => $originalName,
                'status'    => $response['status'] ?? 'uploaded',
                'response'  => $response,
            ];
        } catch (\Throwable $e) {
            throw new RuntimeException('Failed to upload file to backend: ' . $e->getMessage(), 0, $e);
        }
    }

    /**
     * @param array{tmp_name?: string, name: string, type: string, size: int, error: int} $file
     * @throws InvalidArgumentException
     */
    public function validateFile(array $file): bool
    {
        if (empty($file['name'])) {
            throw new InvalidArgumentException('No file name provided.');
        }

        $extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        $allowedExtensions = $this->config['upload']['allowed_extensions'] ?? [];

        if (!in_array($extension, $allowedExtensions, true)) {
            throw new InvalidArgumentException(
                'File type ".' . $extension . '" is not allowed. Accepted: ' . implode(', ', $allowedExtensions)
            );
        }

        $maxSize = $this->config['upload']['max_size'] ?? 104857600;
        if ($file['size'] > $maxSize) {
            $maxMB = round($maxSize / 1048576, 1);
            throw new InvalidArgumentException("File is too large. Maximum size is {$maxMB} MB.");
        }

        if (isset($file['tmp_name']) && file_exists($file['tmp_name'])) {
            $mimeType = mime_content_type($file['tmp_name']);
            $allowedMimes = $this->getAllowedMimeTypes();

            if ($mimeType !== false && !in_array($mimeType, $allowedMimes, true)) {
                throw new InvalidArgumentException(
                    'File MIME type "' . $mimeType . '" is not allowed.'
                );
            }
        }

        return true;
    }

    /**
     * @return string[]
     */
    public function getAllowedMimeTypes(): array
    {
        $extensions = $this->config['upload']['allowed_extensions'] ?? [];
        $mimes = [];

        foreach ($extensions as $ext) {
            $ext = strtolower(trim($ext));
            if (isset(self::MIME_TYPE_MAP[$ext])) {
                $mimes[] = self::MIME_TYPE_MAP[$ext];
            }
        }

        return array_unique($mimes);
    }
}
