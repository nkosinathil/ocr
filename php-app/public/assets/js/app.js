'use strict';

const OCRApp = {
    pollIntervals: new Map(),
    toastTimeout: null,

    init() {
        this.initDragAndDrop();
        this.initJobPolling();
        this.initCancelButtons();
        this.initDashboardRefresh();
        this.initFileInput();
    },

    // --- File Upload with Drag-and-Drop ---

    initDragAndDrop() {
        const dropZone = document.getElementById('drop-zone');
        const fileInput = document.getElementById('file-input');

        if (!dropZone || !fileInput) return;

        ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
            dropZone.addEventListener(eventName, (e) => {
                e.preventDefault();
                e.stopPropagation();
            });
        });

        ['dragenter', 'dragover'].forEach(eventName => {
            dropZone.addEventListener(eventName, () => {
                dropZone.classList.add('drag-over');
            });
        });

        ['dragleave', 'drop'].forEach(eventName => {
            dropZone.addEventListener(eventName, () => {
                dropZone.classList.remove('drag-over');
            });
        });

        dropZone.addEventListener('drop', (e) => {
            const files = e.dataTransfer.files;
            if (files.length > 0) {
                fileInput.files = files;
                this.handleFileSelect(files[0]);
            }
        });

        dropZone.addEventListener('click', () => fileInput.click());
    },

    initFileInput() {
        const fileInput = document.getElementById('file-input');
        if (!fileInput) return;

        fileInput.addEventListener('change', (e) => {
            if (e.target.files.length > 0) {
                this.handleFileSelect(e.target.files[0]);
            }
        });
    },

    handleFileSelect(file) {
        const fileInfo = document.getElementById('file-info');
        const fileName = document.getElementById('file-name');
        const fileSize = document.getElementById('file-size');
        const uploadBtn = document.getElementById('upload-btn');

        if (fileInfo) fileInfo.style.display = 'block';
        if (fileName) fileName.textContent = file.name;
        if (fileSize) fileSize.textContent = this.formatFileSize(file.size);
        if (uploadBtn) uploadBtn.disabled = false;
    },

    // --- Upload with Progress Bar ---

    submitUpload(form) {
        const progressContainer = document.getElementById('progress-container');
        const progressBar = document.getElementById('progress-bar');
        const progressText = document.getElementById('progress-text');
        const uploadBtn = document.getElementById('upload-btn');

        if (!form || !progressContainer) return;

        if (uploadBtn) uploadBtn.disabled = true;
        progressContainer.style.display = 'block';

        const formData = new FormData(form);
        const xhr = new XMLHttpRequest();

        xhr.upload.addEventListener('progress', (e) => {
            if (e.lengthComputable) {
                const percent = Math.round((e.loaded / e.total) * 100);
                if (progressBar) progressBar.style.width = percent + '%';
                if (progressText) progressText.textContent = percent + '%';
            }
        });

        xhr.addEventListener('load', () => {
            if (xhr.status >= 200 && xhr.status < 400) {
                if (progressBar) progressBar.style.width = '100%';
                if (progressText) progressText.textContent = '100% - Redirecting...';
                if (xhr.responseURL) {
                    window.location.href = xhr.responseURL;
                } else {
                    window.location.href = '/jobs';
                }
            } else {
                this.showToast('Upload failed. Please try again.', 'error');
                if (uploadBtn) uploadBtn.disabled = false;
                progressContainer.style.display = 'none';
            }
        });

        xhr.addEventListener('error', () => {
            this.showToast('Network error. Please check your connection.', 'error');
            if (uploadBtn) uploadBtn.disabled = false;
            progressContainer.style.display = 'none';
        });

        xhr.open('POST', form.action || '/upload');
        xhr.send(formData);
    },

    // --- Job Status Polling ---

    initJobPolling() {
        const activeJobs = document.querySelectorAll('[data-job-id][data-job-status]');

        activeJobs.forEach(el => {
            const jobId = el.dataset.jobId;
            const status = el.dataset.jobStatus;

            if (status === 'pending' || status === 'processing') {
                this.startPolling(jobId);
            }
        });
    },

    startPolling(jobId) {
        if (this.pollIntervals.has(jobId)) return;

        const interval = setInterval(() => this.checkJobStatus(jobId), 3000);
        this.pollIntervals.set(jobId, interval);
    },

    stopPolling(jobId) {
        const interval = this.pollIntervals.get(jobId);
        if (interval) {
            clearInterval(interval);
            this.pollIntervals.delete(jobId);
        }
    },

    async checkJobStatus(jobId) {
        try {
            const response = await fetch(`/jobs/${jobId}/status`, {
                headers: { 'Accept': 'application/json' },
            });

            if (!response.ok) return;

            const data = await response.json();
            this.updateJobUI(jobId, data);

            if (data.status === 'completed' || data.status === 'failed' || data.status === 'cancelled') {
                this.stopPolling(jobId);

                if (data.status === 'completed') {
                    this.showToast(`Job #${jobId} completed!`, 'success');
                } else if (data.status === 'failed') {
                    this.showToast(`Job #${jobId} failed.`, 'error');
                }
            }
        } catch (err) {
            console.error(`Polling error for job ${jobId}:`, err);
        }
    },

    updateJobUI(jobId, data) {
        const statusEl = document.querySelector(`[data-job-id="${jobId}"] .job-status`);
        const progressEl = document.querySelector(`[data-job-id="${jobId}"] .job-progress`);

        if (statusEl) {
            statusEl.textContent = data.status;
            statusEl.className = 'job-status badge badge-' + data.status;
        }

        if (progressEl && data.progress !== undefined) {
            progressEl.style.width = data.progress + '%';
            progressEl.textContent = data.progress + '%';
        }

        const detailStatus = document.getElementById('detail-job-status');
        if (detailStatus) {
            detailStatus.textContent = data.status;
            detailStatus.className = 'badge badge-' + data.status;
        }

        if (data.status === 'completed') {
            const resultLink = document.getElementById('result-link');
            if (resultLink) resultLink.style.display = 'inline-block';
        }
    },

    // --- Cancel Confirmation ---

    initCancelButtons() {
        document.querySelectorAll('[data-cancel-job]').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                const jobId = btn.dataset.cancelJob;
                this.confirmCancel(jobId);
            });
        });
    },

    confirmCancel(jobId) {
        if (!confirm(`Are you sure you want to cancel Job #${jobId}? This action cannot be undone.`)) {
            return;
        }

        fetch(`/jobs/${jobId}/cancel`, {
            method: 'POST',
            headers: {
                'Accept': 'application/json',
                'X-Requested-With': 'XMLHttpRequest',
            },
        })
        .then(res => res.json())
        .then(data => {
            if (data.success) {
                this.showToast(`Job #${jobId} cancelled.`, 'success');
                this.stopPolling(jobId);
                if (data.redirect) {
                    window.location.href = data.redirect;
                } else {
                    window.location.reload();
                }
            } else {
                this.showToast('Failed to cancel job.', 'error');
            }
        })
        .catch(() => {
            this.showToast('Network error while cancelling job.', 'error');
        });
    },

    // --- Dashboard Auto-Refresh ---

    initDashboardRefresh() {
        const dashboard = document.getElementById('dashboard-stats');
        if (!dashboard) return;

        setInterval(() => this.refreshDashboard(), 15000);
    },

    async refreshDashboard() {
        try {
            const response = await fetch('/api/v1/ocr/jobs/stats', {
                headers: { 'Accept': 'application/json' },
            });

            if (!response.ok) return;

            const stats = await response.json();

            const fields = ['total', 'completed', 'processing', 'failed', 'pending'];
            fields.forEach(field => {
                const el = document.getElementById('stat-' + field);
                if (el && stats[field] !== undefined) {
                    el.textContent = stats[field];
                }
            });
        } catch (err) {
            console.error('Dashboard refresh error:', err);
        }
    },

    // --- Toast Notifications ---

    showToast(message, type = 'info') {
        let container = document.getElementById('toast-container');
        if (!container) {
            container = document.createElement('div');
            container.id = 'toast-container';
            document.body.appendChild(container);
        }

        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.innerHTML = `
            <span class="toast-message">${this.escapeHtml(message)}</span>
            <button class="toast-close" onclick="this.parentElement.remove()">&times;</button>
        `;

        container.appendChild(toast);

        requestAnimationFrame(() => toast.classList.add('toast-visible'));

        setTimeout(() => {
            toast.classList.remove('toast-visible');
            setTimeout(() => toast.remove(), 300);
        }, 5000);
    },

    // --- Utilities ---

    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    },

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    },
};

document.addEventListener('DOMContentLoaded', () => OCRApp.init());
