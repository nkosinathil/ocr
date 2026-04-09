<?php

declare(strict_types=1);

namespace App\Services;

use RuntimeException;

class ApiService
{
    private string $baseUrl;
    private string $version;
    private int $timeout;

    public function __construct(array $apiConfig)
    {
        $this->baseUrl = rtrim($apiConfig['base_url'] ?? 'http://127.0.0.1:8000', '/');
        $this->version = $apiConfig['version'] ?? 'v1';
        $this->timeout = (int) ($apiConfig['timeout'] ?? 30);
    }

    /**
     * @return array<string, mixed>
     */
    public function get(string $endpoint, array $params = []): array
    {
        $url = $this->buildUrl($endpoint);

        if (!empty($params)) {
            $url .= '?' . http_build_query($params);
        }

        return $this->executeRequest($url, 'GET');
    }

    /**
     * @return array<string, mixed>
     */
    public function post(string $endpoint, array $data = [], array $files = []): array
    {
        $url = $this->buildUrl($endpoint);

        if (!empty($files)) {
            return $this->executeMultipartRequest($url, $data, $files);
        }

        return $this->executeRequest($url, 'POST', json_encode($data), [
            'Content-Type: application/json',
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    public function delete(string $endpoint): array
    {
        $url = $this->buildUrl($endpoint);
        return $this->executeRequest($url, 'DELETE');
    }

    /**
     * @return array<string, mixed>
     */
    public function postFile(string $endpoint, string $filePath, string $fileName, array $extraFields = []): array
    {
        $url = $this->buildUrl($endpoint);

        if (!file_exists($filePath)) {
            throw new RuntimeException("File not found: {$filePath}");
        }

        $mimeType = mime_content_type($filePath) ?: 'application/octet-stream';
        $cFile = new \CURLFile($filePath, $mimeType, $fileName);

        $postData = array_merge($extraFields, ['file' => $cFile]);

        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL            => $url,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $postData,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => $this->timeout * 2, // Longer timeout for file uploads
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_HTTPHEADER     => [
                'Accept: application/json',
            ],
        ]);

        return $this->handleResponse($ch);
    }

    private function buildUrl(string $endpoint): string
    {
        $endpoint = ltrim($endpoint, '/');

        if (!str_starts_with($endpoint, 'api/')) {
            return $this->baseUrl . '/api/' . $this->version . '/' . $endpoint;
        }

        return $this->baseUrl . '/' . $endpoint;
    }

    /**
     * @param string[] $extraHeaders
     * @return array<string, mixed>
     */
    private function executeRequest(string $url, string $method, ?string $body = null, array $extraHeaders = []): array
    {
        $ch = curl_init();

        $headers = array_merge([
            'Accept: application/json',
        ], $extraHeaders);

        $options = [
            CURLOPT_URL            => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => $this->timeout,
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_CUSTOMREQUEST  => $method,
            CURLOPT_HTTPHEADER     => $headers,
        ];

        if ($body !== null && in_array($method, ['POST', 'PUT', 'PATCH'], true)) {
            $options[CURLOPT_POSTFIELDS] = $body;
        }

        $token = $_SESSION['access_token'] ?? null;
        if ($token !== null) {
            $options[CURLOPT_HTTPHEADER][] = 'Authorization: Bearer ' . $token;
        }

        curl_setopt_array($ch, $options);

        return $this->handleResponse($ch);
    }

    /**
     * @return array<string, mixed>
     */
    private function executeMultipartRequest(string $url, array $fields, array $files): array
    {
        $postData = $fields;

        foreach ($files as $fieldName => $fileInfo) {
            $filePath = $fileInfo['tmp_name'] ?? $fileInfo['path'] ?? '';
            $fileName = $fileInfo['name'] ?? basename($filePath);
            $mimeType = $fileInfo['type'] ?? (mime_content_type($filePath) ?: 'application/octet-stream');

            if (!file_exists($filePath)) {
                throw new RuntimeException("File not found: {$filePath}");
            }

            $postData[$fieldName] = new \CURLFile($filePath, $mimeType, $fileName);
        }

        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL            => $url,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $postData,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => $this->timeout * 2,
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_HTTPHEADER     => ['Accept: application/json'],
        ]);

        return $this->handleResponse($ch);
    }

    /**
     * @return array<string, mixed>
     */
    private function handleResponse(\CurlHandle $ch): array
    {
        $response = curl_exec($ch);
        $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        $errno = curl_errno($ch);
        curl_close($ch);

        if ($response === false || $errno !== 0) {
            throw new RuntimeException('API request failed: ' . $error, $errno);
        }

        if ($httpCode === 0) {
            throw new RuntimeException('API server unreachable');
        }

        $decoded = json_decode((string) $response, true);

        if ($decoded === null && json_last_error() !== JSON_ERROR_NONE) {
            if ($httpCode >= 400) {
                throw new RuntimeException("API returned HTTP {$httpCode} with non-JSON response", $httpCode);
            }
            return ['raw_response' => $response, 'http_code' => $httpCode];
        }

        if ($httpCode >= 400) {
            $message = $decoded['detail'] ?? $decoded['error'] ?? $decoded['message'] ?? "HTTP {$httpCode}";
            throw new RuntimeException('API error: ' . (is_string($message) ? $message : json_encode($message)), $httpCode);
        }

        return $decoded ?? [];
    }
}
