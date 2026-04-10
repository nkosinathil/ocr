<?php
declare(strict_types=1);

namespace MxaOcr\Models;

/**
 * Job Model
 * 
 * Represents an OCR processing job.
 */
class Job
{
    public string $id;
    public string $userId;
    public string $status;
    public int $priority;
    public string $originalFilename;
    public int $fileSize;
    public string $fileType;
    public string $minioInputPath;
    public ?string $minioOutputPath;
    public string $submittedAt;
    public ?string $startedAt;
    public ?string $completedAt;
    public ?string $errorMessage;
    public int $retryCount;
    public array $metadata;
    public string $createdAt;
    public string $updatedAt;
    
    public function __construct(array $data)
    {
        $this->id = $data['id'] ?? '';
        $this->userId = $data['user_id'] ?? '';
        $this->status = $data['status'] ?? 'pending';
        $this->priority = (int)($data['priority'] ?? 5);
        $this->originalFilename = $data['original_filename'] ?? '';
        $this->fileSize = (int)($data['file_size'] ?? 0);
        $this->fileType = $data['file_type'] ?? '';
        $this->minioInputPath = $data['minio_input_path'] ?? '';
        $this->minioOutputPath = $data['minio_output_path'] ?? null;
        $this->submittedAt = $data['submitted_at'] ?? '';
        $this->startedAt = $data['started_at'] ?? null;
        $this->completedAt = $data['completed_at'] ?? null;
        $this->errorMessage = $data['error_message'] ?? null;
        $this->retryCount = (int)($data['retry_count'] ?? 0);
        $this->metadata = isset($data['metadata']) ? json_decode($data['metadata'], true) : [];
        $this->createdAt = $data['created_at'] ?? '';
        $this->updatedAt = $data['updated_at'] ?? '';
    }
    
    /**
     * Check if job is pending
     */
    public function isPending(): bool
    {
        return $this->status === 'pending';
    }
    
    /**
     * Check if job is processing
     */
    public function isProcessing(): bool
    {
        return $this->status === 'processing';
    }
    
    /**
     * Check if job is completed
     */
    public function isCompleted(): bool
    {
        return $this->status === 'completed';
    }
    
    /**
     * Check if job failed
     */
    public function isFailed(): bool
    {
        return $this->status === 'failed';
    }
    
    /**
     * Check if job was cancelled
     */
    public function isCancelled(): bool
    {
        return $this->status === 'cancelled';
    }
    
    /**
     * Check if job is in final state
     */
    public function isFinished(): bool
    {
        return in_array($this->status, ['completed', 'failed', 'cancelled'], true);
    }
    
    /**
     * Get processing duration in seconds
     */
    public function getProcessingDuration(): ?int
    {
        if (!$this->startedAt || !$this->completedAt) {
            return null;
        }
        
        $start = new \DateTime($this->startedAt);
        $end = new \DateTime($this->completedAt);
        return $end->getTimestamp() - $start->getTimestamp();
    }
    
    /**
     * Convert to array
     */
    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->userId,
            'status' => $this->status,
            'priority' => $this->priority,
            'original_filename' => $this->originalFilename,
            'file_size' => $this->fileSize,
            'file_type' => $this->fileType,
            'minio_input_path' => $this->minioInputPath,
            'minio_output_path' => $this->minioOutputPath,
            'submitted_at' => $this->submittedAt,
            'started_at' => $this->startedAt,
            'completed_at' => $this->completedAt,
            'error_message' => $this->errorMessage,
            'retry_count' => $this->retryCount,
            'metadata' => $this->metadata,
            'created_at' => $this->createdAt,
            'updated_at' => $this->updatedAt,
        ];
    }
}
