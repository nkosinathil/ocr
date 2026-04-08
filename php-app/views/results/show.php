<?php
$title = 'OCR Results';
$result = $result ?? [];
$jobId = $jobId ?? '';
$pages = $result['pages'] ?? [];
$fullText = $result['full_text'] ?? $result['text'] ?? $result['extracted_text'] ?? '';
$totalWords = $result['total_word_count'] ?? 0;
?>

<div class="mb-3">
    <div class="breadcrumb">
        <a href="/jobs">Jobs</a>
        <span class="separator">/</span>
        <a href="/jobs/<?= htmlspecialchars((string)$jobId) ?>">#<?= htmlspecialchars(substr((string)$jobId, 0, 8)) ?></a>
        <span class="separator">/</span>
        <span>Results</span>
    </div>
</div>

<div class="card mb-3">
    <div class="card-header">
        <div>
            <div class="card-title">OCR Results</div>
            <div class="card-subtitle">Extracted text from Job #<?= htmlspecialchars(substr((string)$jobId, 0, 8)) ?></div>
        </div>
        <div class="d-flex gap-1">
            <button class="btn btn-secondary btn-sm" onclick="OCRApp.copyResultText()">&#128203; Copy Text</button>
            <a href="/results/<?= htmlspecialchars((string)$jobId) ?>/download" class="btn btn-primary btn-sm">&#11015; Download TXT</a>
        </div>
    </div>

    <div class="card-body">
        <div class="result-meta mb-3">
            <div class="result-meta-item">
                <span class="result-meta-label">Total Pages</span>
                <span class="result-meta-value"><?= count($pages) ?: 1 ?></span>
            </div>
            <div class="result-meta-item">
                <span class="result-meta-label">Word Count</span>
                <span class="result-meta-value"><?= number_format($totalWords) ?></span>
            </div>
            <div class="result-meta-item">
                <span class="result-meta-label">Format</span>
                <span class="result-meta-value"><?= htmlspecialchars($result['format'] ?? 'text') ?></span>
            </div>
            <?php if (!empty($pages)): ?>
            <div class="result-meta-item">
                <span class="result-meta-label">Avg Confidence</span>
                <?php
                $confidences = array_filter(array_column($pages, 'confidence_score'));
                $avgConf = count($confidences) > 0 ? array_sum($confidences) / count($confidences) : 0;
                ?>
                <span class="result-meta-value"><?= number_format($avgConf, 1) ?>%</span>
            </div>
            <?php endif; ?>
        </div>

        <?php if (count($pages) > 1): ?>
        <div class="page-tabs mb-3">
            <div class="page-tab active" onclick="OCRApp.showResultPage('all', this)">All Pages</div>
            <?php foreach ($pages as $i => $pg): ?>
            <div class="page-tab" onclick="OCRApp.showResultPage(<?= $i ?>, this)">
                Page <?= ($pg['page_number'] ?? $i + 1) ?>
            </div>
            <?php endforeach; ?>
        </div>
        <?php endif; ?>

        <div id="result-all" class="result-page-content">
            <div class="result-text-block" id="resultTextBlock"><?= htmlspecialchars($fullText) ?></div>
        </div>

        <?php foreach ($pages as $i => $pg): ?>
        <div id="result-<?= $i ?>" class="result-page-content hidden">
            <div class="d-flex justify-between align-center mb-1">
                <span class="text-sm font-medium">Page <?= ($pg['page_number'] ?? $i + 1) ?></span>
                <span class="text-xs text-muted">
                    <?= number_format($pg['word_count'] ?? 0) ?> words
                    <?php if (!empty($pg['confidence_score'])): ?>
                        &middot; <?= number_format($pg['confidence_score'], 1) ?>% confidence
                    <?php endif; ?>
                </span>
            </div>
            <div class="result-text-block"><?= htmlspecialchars($pg['text'] ?? '') ?></div>
        </div>
        <?php endforeach; ?>
    </div>

    <div class="card-footer d-flex gap-2">
        <a href="/jobs/<?= htmlspecialchars((string)$jobId) ?>" class="btn btn-secondary btn-sm">&larr; Back to Job</a>
        <a href="/jobs" class="btn btn-ghost btn-sm">All Jobs</a>
    </div>
</div>
