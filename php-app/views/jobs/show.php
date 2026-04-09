<?php
$title = 'Job Details';
$job = $job ?? [];
$jobId = $job['job_id'] ?? $job['id'] ?? $jobId ?? '';
$status = $job['status'] ?? 'pending';
$isActive = in_array($status, ['pending', 'queued', 'processing']);
?>

<div class="mb-3">
    <div class="breadcrumb">
        <a href="/jobs">Jobs</a>
        <span class="separator">/</span>
        <span>#<?= htmlspecialchars(substr((string)$jobId, 0, 8)) ?></span>
    </div>
</div>

<div style="display: grid; grid-template-columns: 2fr 1fr; gap: 24px;">
    <div>
        <div class="card mb-3">
            <div class="card-header">
                <div>
                    <div class="card-title">Job #<?= htmlspecialchars(substr((string)$jobId, 0, 8)) ?></div>
                    <div class="card-subtitle">Processing details and status</div>
                </div>
                <span class="badge badge-<?= htmlspecialchars($status) ?>" id="job-status-badge">
                    <span class="badge-dot"></span>
                    <?= ucfirst(htmlspecialchars($status)) ?>
                </span>
            </div>
            <div class="card-body">
                <div class="result-meta mb-3">
                    <div class="result-meta-item">
                        <span class="result-meta-label">File</span>
                        <span class="result-meta-value"><?= htmlspecialchars($job['original_filename'] ?? 'Unknown') ?></span>
                    </div>
                    <div class="result-meta-item">
                        <span class="result-meta-label">Engine</span>
                        <span class="result-meta-value"><?= htmlspecialchars($job['engine'] ?? 'tesseract') ?></span>
                    </div>
                    <div class="result-meta-item">
                        <span class="result-meta-label">Language</span>
                        <span class="result-meta-value"><?= htmlspecialchars($job['language'] ?? 'eng') ?></span>
                    </div>
                    <div class="result-meta-item">
                        <span class="result-meta-label">Priority</span>
                        <span class="result-meta-value"><?= (int)($job['priority'] ?? 0) ?></span>
                    </div>
                </div>

                <div class="mb-2">
                    <div class="d-flex justify-between align-center mb-1">
                        <span class="text-sm font-medium">Progress</span>
                        <span class="text-sm text-muted" id="progress-label"><?= (int)($job['progress_percent'] ?? 0) ?>%</span>
                    </div>
                    <div class="progress-bar-wrapper" style="height: 10px;">
                        <div class="progress-bar <?= $status === 'completed' ? 'completed' : ($status === 'failed' ? 'failed' : '') ?>"
                             id="job-progress-bar"
                             style="width: <?= (int)($job['progress_percent'] ?? 0) ?>%">
                        </div>
                    </div>
                    <div class="text-xs text-muted mt-1" id="pages-info">
                        <?= (int)($job['pages_processed'] ?? 0) ?> of <?= (int)($job['pages_total'] ?? 0) ?> pages processed
                    </div>
                </div>

                <?php if (!empty($job['error_message'])): ?>
                <div class="flash-message flash-error mt-2">
                    <span>&#9888;</span>
                    <?= htmlspecialchars($job['error_message']) ?>
                </div>
                <?php endif; ?>
            </div>

            <div class="card-footer d-flex gap-2">
                <?php if ($status === 'completed'): ?>
                    <a href="/results/<?= htmlspecialchars((string)$jobId) ?>" class="btn btn-success btn-sm">&#128196; View Results</a>
                    <a href="/results/<?= htmlspecialchars((string)$jobId) ?>/download" class="btn btn-secondary btn-sm">&#11015; Download</a>
                <?php endif; ?>
                <?php if ($isActive): ?>
                    <button class="btn btn-danger btn-sm" onclick="OCRApp.cancelJob('<?= htmlspecialchars((string)$jobId) ?>')">&#10007; Cancel Job</button>
                <?php endif; ?>
                <a href="/jobs" class="btn btn-secondary btn-sm">&larr; Back to Jobs</a>
            </div>
        </div>
    </div>

    <div>
        <div class="card">
            <div class="card-header">
                <div class="card-title">Timeline</div>
            </div>
            <div class="card-body">
                <div class="timeline">
                    <div class="timeline-item">
                        <div class="timeline-dot active"></div>
                        <div class="timeline-time"><?= !empty($job['created_at']) ? date('M j, Y H:i:s', strtotime($job['created_at'])) : '-' ?></div>
                        <div class="timeline-text">Job created</div>
                    </div>
                    <?php if (!empty($job['started_at'])): ?>
                    <div class="timeline-item">
                        <div class="timeline-dot active"></div>
                        <div class="timeline-time"><?= date('M j, Y H:i:s', strtotime($job['started_at'])) ?></div>
                        <div class="timeline-text">Processing started</div>
                    </div>
                    <?php endif; ?>
                    <?php if ($status === 'completed' && !empty($job['completed_at'])): ?>
                    <div class="timeline-item">
                        <div class="timeline-dot success"></div>
                        <div class="timeline-time"><?= date('M j, Y H:i:s', strtotime($job['completed_at'])) ?></div>
                        <div class="timeline-text">Processing completed</div>
                    </div>
                    <?php elseif ($status === 'failed'): ?>
                    <div class="timeline-item">
                        <div class="timeline-dot error"></div>
                        <div class="timeline-time"><?= !empty($job['updated_at']) ? date('M j, Y H:i:s', strtotime($job['updated_at'])) : '-' ?></div>
                        <div class="timeline-text">Processing failed</div>
                    </div>
                    <?php endif; ?>
                </div>
            </div>
        </div>

        <div class="card mt-3">
            <div class="card-header">
                <div class="card-title">Details</div>
            </div>
            <div class="card-body">
                <table style="width: 100%; font-size: 13px;">
                    <tr>
                        <td class="text-muted" style="padding: 6px 0; width: 40%;">Job ID</td>
                        <td class="font-medium" style="padding: 6px 0;"><?= htmlspecialchars((string)$jobId) ?></td>
                    </tr>
                    <tr>
                        <td class="text-muted" style="padding: 6px 0;">Upload ID</td>
                        <td style="padding: 6px 0;"><?= htmlspecialchars($job['upload_id'] ?? '-') ?></td>
                    </tr>
                    <tr>
                        <td class="text-muted" style="padding: 6px 0;">Celery Task</td>
                        <td class="text-sm" style="padding: 6px 0;"><?= htmlspecialchars(substr($job['celery_task_id'] ?? '-', 0, 16)) ?></td>
                    </tr>
                    <tr>
                        <td class="text-muted" style="padding: 6px 0;">Created</td>
                        <td style="padding: 6px 0;"><?= !empty($job['created_at']) ? date('M j, Y H:i', strtotime($job['created_at'])) : '-' ?></td>
                    </tr>
                    <tr>
                        <td class="text-muted" style="padding: 6px 0;">Updated</td>
                        <td style="padding: 6px 0;"><?= !empty($job['updated_at']) ? date('M j, Y H:i', strtotime($job['updated_at'])) : '-' ?></td>
                    </tr>
                </table>
            </div>
        </div>
    </div>
</div>

<?php if ($isActive): ?>
<script>
document.addEventListener('DOMContentLoaded', function() {
    OCRApp.pollJobStatus('<?= htmlspecialchars((string)$jobId) ?>');
});
</script>
<?php endif; ?>
