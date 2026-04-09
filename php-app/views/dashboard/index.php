<?php
$title = 'Dashboard';
$totalJobs = ($stats['total'] ?? 0);
$completed = ($stats['completed'] ?? 0);
$processing = ($stats['processing'] ?? 0);
$failed = ($stats['failed'] ?? 0);
$queued = ($stats['queued'] ?? 0) + ($stats['pending'] ?? 0);
?>

<div class="stats-grid">
    <div class="stat-card">
        <div class="stat-icon blue">&#9633;</div>
        <div class="stat-content">
            <div class="stat-value"><?= number_format($totalJobs) ?></div>
            <div class="stat-label">Total Jobs</div>
        </div>
    </div>
    <div class="stat-card">
        <div class="stat-icon green">&#10003;</div>
        <div class="stat-content">
            <div class="stat-value"><?= number_format($completed) ?></div>
            <div class="stat-label">Completed</div>
        </div>
    </div>
    <div class="stat-card">
        <div class="stat-icon amber">&#8635;</div>
        <div class="stat-content">
            <div class="stat-value"><?= number_format($processing) ?></div>
            <div class="stat-label">Processing</div>
        </div>
    </div>
    <div class="stat-card">
        <div class="stat-icon purple">&#8987;</div>
        <div class="stat-content">
            <div class="stat-value"><?= number_format($queued) ?></div>
            <div class="stat-label">In Queue</div>
        </div>
    </div>
    <div class="stat-card">
        <div class="stat-icon red">&#10007;</div>
        <div class="stat-content">
            <div class="stat-value"><?= number_format($failed) ?></div>
            <div class="stat-label">Failed</div>
        </div>
    </div>
</div>

<div class="card">
    <div class="card-header">
        <div>
            <div class="card-title">Recent Jobs</div>
            <div class="card-subtitle">Latest OCR processing jobs</div>
        </div>
        <a href="/jobs" class="btn btn-secondary btn-sm">View All</a>
    </div>

    <?php if (empty($recentJobs)): ?>
        <div class="card-body">
            <div class="empty-state">
                <div class="empty-state-icon">&#128196;</div>
                <div class="empty-state-title">No jobs yet</div>
                <div class="empty-state-text">Upload a document to get started with OCR processing.</div>
                <a href="/upload" class="btn btn-primary">&#8682; Upload Document</a>
            </div>
        </div>
    <?php else: ?>
        <div class="table-wrapper">
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Job ID</th>
                        <th>File</th>
                        <th>Status</th>
                        <th>Progress</th>
                        <th>Engine</th>
                        <th>Created</th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($recentJobs as $job): ?>
                    <tr>
                        <?php $jid = $job['job_id'] ?? $job['id'] ?? ''; ?>
                        <td class="font-medium">#<?= htmlspecialchars(substr($jid, 0, 8)) ?></td>
                        <td class="truncate" style="max-width: 200px;"><?= htmlspecialchars($job['original_filename'] ?? 'Unknown') ?></td>
                        <td>
                            <span class="badge badge-<?= htmlspecialchars($job['status'] ?? 'pending') ?>">
                                <span class="badge-dot"></span>
                                <?= ucfirst(htmlspecialchars($job['status'] ?? 'pending')) ?>
                            </span>
                        </td>
                        <td>
                            <div class="progress-bar-wrapper" style="width: 80px;">
                                <div class="progress-bar <?= ($job['status'] ?? '') === 'completed' ? 'completed' : (($job['status'] ?? '') === 'failed' ? 'failed' : '') ?>"
                                     style="width: <?= (int)($job['progress_percent'] ?? 0) ?>%">
                                </div>
                            </div>
                            <span class="text-xs text-muted"><?= (int)($job['progress_percent'] ?? 0) ?>%</span>
                        </td>
                        <td class="text-sm text-muted"><?= htmlspecialchars($job['engine'] ?? 'tesseract') ?></td>
                        <td class="text-sm text-muted"><?= !empty($job['created_at']) ? date('M j, H:i', strtotime($job['created_at'])) : '-' ?></td>
                        <td>
                            <a href="/jobs/<?= htmlspecialchars($jid) ?>" class="btn btn-ghost btn-sm">View</a>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</div>
