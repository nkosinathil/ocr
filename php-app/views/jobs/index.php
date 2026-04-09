<?php
$title = 'OCR Jobs';
$jobs = $jobs ?? [];
$page = $page ?? 1;
$totalPages = $totalPages ?? 1;
?>

<div class="d-flex align-center justify-between mb-3">
    <div>
        <span class="text-muted text-sm"><?= number_format($total ?? 0) ?> jobs total</span>
    </div>
    <a href="/upload" class="btn btn-primary btn-sm">&#8682; New Upload</a>
</div>

<?php if (empty($jobs)): ?>
<div class="card">
    <div class="card-body">
        <div class="empty-state">
            <div class="empty-state-icon">&#128196;</div>
            <div class="empty-state-title">No OCR jobs found</div>
            <div class="empty-state-text">Upload a document to create your first OCR processing job.</div>
            <a href="/upload" class="btn btn-primary">&#8682; Upload Document</a>
        </div>
    </div>
</div>
<?php else: ?>
<div class="card">
    <div class="table-wrapper">
        <table class="data-table" id="jobsTable">
            <thead>
                <tr>
                    <th>Job ID</th>
                    <th>File</th>
                    <th>Status</th>
                    <th>Progress</th>
                    <th>Pages</th>
                    <th>Engine</th>
                    <th>Language</th>
                    <th>Created</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($jobs as $job): ?>
                <?php $jid = $job['job_id'] ?? $job['id'] ?? ''; ?>
                <tr id="job-row-<?= htmlspecialchars($jid) ?>" data-job-id="<?= htmlspecialchars($jid) ?>">
                    <td class="font-medium">
                        <a href="/jobs/<?= htmlspecialchars($jid) ?>">#<?= htmlspecialchars(substr($jid, 0, 8)) ?></a>
                    </td>
                    <td>
                        <div class="d-flex align-center gap-1">
                            <?php
                            $ext = strtolower(pathinfo($job['original_filename'] ?? '', PATHINFO_EXTENSION));
                            $iconClass = 'file-icon-' . $ext;
                            ?>
                            <div class="file-icon <?= $iconClass ?>"><?= strtoupper($ext) ?: '?' ?></div>
                            <span class="truncate" style="max-width: 180px;"><?= htmlspecialchars($job['original_filename'] ?? 'Unknown') ?></span>
                        </div>
                    </td>
                    <td>
                        <span class="badge badge-<?= htmlspecialchars($job['status'] ?? 'pending') ?>" id="status-<?= htmlspecialchars($jid) ?>">
                            <span class="badge-dot"></span>
                            <?= ucfirst(htmlspecialchars($job['status'] ?? 'pending')) ?>
                        </span>
                    </td>
                    <td>
                        <div class="d-flex align-center gap-1">
                            <div class="progress-bar-wrapper" style="width: 64px;">
                                <div class="progress-bar <?= ($job['status'] ?? '') === 'completed' ? 'completed' : (($job['status'] ?? '') === 'failed' ? 'failed' : '') ?>"
                                     id="progress-<?= htmlspecialchars($jid) ?>"
                                     style="width: <?= (int)($job['progress_percent'] ?? 0) ?>%">
                                </div>
                            </div>
                            <span class="text-xs text-muted"><?= (int)($job['progress_percent'] ?? 0) ?>%</span>
                        </div>
                    </td>
                    <td class="text-sm text-muted">
                        <?= (int)($job['pages_processed'] ?? 0) ?>/<?= (int)($job['pages_total'] ?? 0) ?>
                    </td>
                    <td class="text-sm text-muted"><?= htmlspecialchars($job['engine'] ?? 'tesseract') ?></td>
                    <td class="text-sm text-muted"><?= htmlspecialchars($job['language'] ?? 'eng') ?></td>
                    <td class="text-sm text-muted">
                        <?= !empty($job['created_at']) ? date('M j, H:i', strtotime($job['created_at'])) : '-' ?>
                    </td>
                    <td>
                        <div class="d-flex gap-1">
                            <a href="/jobs/<?= htmlspecialchars($jid) ?>" class="btn btn-ghost btn-sm">View</a>
                            <?php if (($job['status'] ?? '') === 'completed'): ?>
                                <a href="/results/<?= htmlspecialchars($jid) ?>" class="btn btn-ghost btn-sm text-success">Results</a>
                            <?php endif; ?>
                            <?php if (in_array($job['status'] ?? '', ['pending', 'queued', 'processing'])): ?>
                                <button class="btn btn-ghost btn-sm text-danger" onclick="OCRApp.cancelJob('<?= htmlspecialchars($jid) ?>')">Cancel</button>
                            <?php endif; ?>
                        </div>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>

    <?php if ($totalPages > 1): ?>
    <div class="card-footer">
        <div class="pagination">
            <?php if ($page > 1): ?>
                <a href="/jobs?page=<?= $page - 1 ?>">&laquo;</a>
            <?php else: ?>
                <span class="disabled">&laquo;</span>
            <?php endif; ?>

            <?php for ($i = max(1, $page - 2); $i <= min($totalPages, $page + 2); $i++): ?>
                <?php if ($i === $page): ?>
                    <span class="active"><?= $i ?></span>
                <?php else: ?>
                    <a href="/jobs?page=<?= $i ?>"><?= $i ?></a>
                <?php endif; ?>
            <?php endfor; ?>

            <?php if ($page < $totalPages): ?>
                <a href="/jobs?page=<?= $page + 1 ?>">&raquo;</a>
            <?php else: ?>
                <span class="disabled">&raquo;</span>
            <?php endif; ?>
        </div>
    </div>
    <?php endif; ?>
</div>
<?php endif; ?>
