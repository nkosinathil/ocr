<?php
declare(strict_types=1);

namespace MxaOcr\Services;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;
use MxaOcr\Config\Environment;

/**
 * Python API Client
 * 
 * HTTP client for communicating with the Python FastAPI backend.
 * Handles job submission, status checks, and result retrieval.
 */
class PythonApiClient
{
    private Client $client;
    private string $baseUrl;
    private int $timeout;
    private ?string $apiKey;
    
    public function __construct()
    {
        $env = Environment::getInstance();
        
        $this->baseUrl = rtrim($env->getConfig('python_api.url'), '/');
        $this->timeout = $env->getConfig('python_api.timeout', 30);
        $this->apiKey = $env->getConfig('python_api.api_key');
        
        $this->client = new Client([
            'base_uri' => $this->baseUrl,
            'timeout' => $this->timeout,
            'headers' => array_filter([
                'Content-Type' => 'application/json',
                'Accept' => 'application/json',
                'X-API-Key' => $this->apiKey,
            ]),
        ]);
    }
    
    /**
     * Submit a new OCR job
     */
    public function submitJob(array $jobData): ?array
    {
        try {
            $response = $this->client->post('/api/v1/jobs', [
                'json' => $jobData,
            ]);
            
            if ($response->getStatusCode() === 201 || $response->getStatusCode() === 200) {
                return json_decode($response->getBody()->getContents(), true);
            }
            
            return null;
        } catch (GuzzleException $e) {
            error_log("Failed to submit job to Python API: " . $e->getMessage());
            return null;
        }
    }
    
    /**
     * Get job status
     */
    public function getJobStatus(string $jobId): ?array
    {
        try {
            $response = $this->client->get("/api/v1/jobs/{$jobId}");
            
            if ($response->getStatusCode() === 200) {
                return json_decode($response->getBody()->getContents(), true);
            }
            
            return null;
        } catch (GuzzleException $e) {
            error_log("Failed to get job status: " . $e->getMessage());
            return null;
        }
    }
    
    /**
     * Get job results
     */
    public function getJobResults(string $jobId): ?array
    {
        try {
            $response = $this->client->get("/api/v1/results/{$jobId}");
            
            if ($response->getStatusCode() === 200) {
                return json_decode($response->getBody()->getContents(), true);
            }
            
            return null;
        } catch (GuzzleException $e) {
            error_log("Failed to get job results: " . $e->getMessage());
            return null;
        }
    }
    
    /**
     * List all jobs
     */
    public function listJobs(array $filters = []): ?array
    {
        try {
            $response = $this->client->get('/api/v1/jobs', [
                'query' => $filters,
            ]);
            
            if ($response->getStatusCode() === 200) {
                return json_decode($response->getBody()->getContents(), true);
            }
            
            return null;
        } catch (GuzzleException $e) {
            error_log("Failed to list jobs: " . $e->getMessage());
            return null;
        }
    }
    
    /**
     * Cancel a job
     */
    public function cancelJob(string $jobId): bool
    {
        try {
            $response = $this->client->delete("/api/v1/jobs/{$jobId}");
            return $response->getStatusCode() === 200 || $response->getStatusCode() === 204;
        } catch (GuzzleException $e) {
            error_log("Failed to cancel job: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Health check
     */
    public function healthCheck(): bool
    {
        try {
            $response = $this->client->get('/api/v1/health');
            return $response->getStatusCode() === 200;
        } catch (GuzzleException $e) {
            return false;
        }
    }
}
