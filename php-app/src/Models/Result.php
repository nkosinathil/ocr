<?php
declare(strict_types=1);

namespace MxaOcr\Models;

/**
 * Result Model
 * 
 * Represents OCR extraction results.
 */
class Result
{
    public string $id;
    public string $jobId;
    public ?string $extractedText;
    public ?int $pageCount;
    public ?float $confidenceScore;
    public ?string $languageDetected;
    public ?int $processingTimeMs;
    public array $outputFormats;
    public array $metadata;
    public string $createdAt;
    
    public function __construct(array $data)
    {
        $this->id = $data['id'] ?? '';
        $this->jobId = $data['job_id'] ?? '';
        $this->extractedText = $data['extracted_text'] ?? null;
        $this->pageCount = isset($data['page_count']) ? (int)$data['page_count'] : null;
        $this->confidenceScore = isset($data['confidence_score']) ? (float)$data['confidence_score'] : null;
        $this->languageDetected = $data['language_detected'] ?? null;
        $this->processingTimeMs = isset($data['processing_time_ms']) ? (int)$data['processing_time_ms'] : null;
        $this->outputFormats = isset($data['output_formats']) ? json_decode($data['output_formats'], true) : [];
        $this->metadata = isset($data['metadata']) ? json_decode($data['metadata'], true) : [];
        $this->createdAt = $data['created_at'] ?? '';
    }
    
    /**
     * Get processing time in seconds
     */
    public function getProcessingTimeSeconds(): ?float
    {
        return $this->processingTimeMs !== null ? $this->processingTimeMs / 1000 : null;
    }
    
    /**
     * Get text preview (first N characters)
     */
    public function getTextPreview(int $length = 200): ?string
    {
        if (!$this->extractedText) {
            return null;
        }
        
        if (mb_strlen($this->extractedText) <= $length) {
            return $this->extractedText;
        }
        
        return mb_substr($this->extractedText, 0, $length) . '...';
    }
    
    /**
     * Convert to array
     */
    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'job_id' => $this->jobId,
            'extracted_text' => $this->extractedText,
            'page_count' => $this->pageCount,
            'confidence_score' => $this->confidenceScore,
            'language_detected' => $this->languageDetected,
            'processing_time_ms' => $this->processingTimeMs,
            'output_formats' => $this->outputFormats,
            'metadata' => $this->metadata,
            'created_at' => $this->createdAt,
        ];
    }
}
