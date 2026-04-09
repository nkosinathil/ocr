'use strict';

const OCRApp = {
    pollIntervals: new Map(),

    init() {
        this.initSidebar();
        this.initDragAndDrop();
        this.initFileInput();
        this.initFlashAutoHide();
    },

    // ---- Sidebar Mobile Toggle ----

    initSidebar() {
        const toggle = document.getElementById('menuToggle');
        const sidebar = document.getElementById('sidebar');
        const overlay = document.getElementById('sidebarOverlay');

        if (!toggle || !sidebar) return;

        toggle.addEventListener('click', () => {
            sidebar.classList.toggle('open');
            if (overlay) overlay.classList.toggle('active');
        });

        if (overlay) {
            overlay.addEventListener('click', () => {
                sidebar.classList.remove('open');
                overlay.classList.remove('active');
            });
        }
    },

    // ---- Drag & Drop Upload ----

    initDragAndDrop() {
        const zone = document.getElementById('uploadZone');
        const input = document.getElementById('fileInput');
        if (!zone || !input) return;

        ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(evt => {
            zone.addEventListener(evt, e => { e.preventDefault(); e.stopPropagation(); });
        });

        ['dragenter', 'dragover'].forEach(evt => {
            zone.addEventListener(evt, () => zone.classList.add('drag-over'));
        });

        ['dragleave', 'drop'].forEach(evt => {
            zone.addEventListener(evt, () => zone.classList.remove('drag-over'));
        });

        zone.addEventListener('drop', e => {
            const files = e.dataTransfer.files;
            if (files.length > 0) {
                input.files = files;
                this.handleFileSelect(files[0]);
            }
        });

        zone.addEventListener('click', () => input.click());
    },

    initFileInput() {
        const input = document.getElementById('fileInput');
        if (!input) return;

        input.addEventListener('change', e => {
            if (e.target.files.length > 0) {
                this.handleFileSelect(e.target.files[0]);
            }
        });
    },

    handleFileSelect(file) {
        const preview = document.getElementById('filePreview');
        const nameEl = document.getElementById('fileName');
        const sizeEl = document.getElementById('fileSize');
        const iconEl = document.getElementById('fileTypeIcon');
        const submitBtn = document.getElementById('submitBtn');
        const removeBtn = document.getElementById('removeFile');

        if (preview) preview.classList.remove('hidden');
        if (nameEl) nameEl.textContent = file.name;
        if (sizeEl) sizeEl.textContent = this.formatFileSize(file.size);
        if (submitBtn) submitBtn.disabled = false;

        if (iconEl) {
            const ext = file.name.split('.').pop().toLowerCase();
            iconEl.textContent = ext.toUpperCase();
            iconEl.className = 'file-icon file-icon-' + ext;
        }

        if (removeBtn) {
            removeBtn.addEventListener('click', () => {
                const input = document.getElementById('fileInput');
                if (input) input.value = '';
                if (preview) preview.classList.add('hidden');
                if (submitBtn) submitBtn.disabled = true;
            }, { once: true });
        }
    },

    // ---- Upload Form Submission with Progress ----

    submitUpload(form) {
        if (!form) return false;

        const submitBtn = document.getElementById('submitBtn');
        const progressWrap = document.getElementById('uploadProgress');
        const progressBar = document.getElementById('progressBar');
        const progressText = document.getElementById('progressText');

        if (submitBtn) submitBtn.disabled = true;
        if (progressWrap) progressWrap.classList.remove('hidden');

        const formData = new FormData(form);
        const xhr = new XMLHttpRequest();

        xhr.upload.addEventListener('progress', e => {
            if (e.lengthComputable) {
                const pct = Math.round((e.loaded / e.total) * 100);
                if (progressBar) progressBar.style.width = pct + '%';
                if (progressText) progressText.textContent = 'Uploading... ' + pct + '%';
            }
        });

        xhr.addEventListener('load', () => {
            if (xhr.status >= 200 && xhr.status < 400) {
                if (progressBar) progressBar.style.width = '100%';
                if (progressText) progressText.textContent = 'Upload complete. Redirecting...';
                setTimeout(() => { window.location.href = xhr.responseURL || '/jobs'; }, 500);
            } else {
                this.showToast('Upload failed. Please try again.', 'error');
                if (submitBtn) submitBtn.disabled = false;
                if (progressWrap) progressWrap.classList.add('hidden');
            }
        });

        xhr.addEventListener('error', () => {
            this.showToast('Network error during upload.', 'error');
            if (submitBtn) submitBtn.disabled = false;
            if (progressWrap) progressWrap.classList.add('hidden');
        });

        xhr.open('POST', form.action || '/upload');
        xhr.send(formData);
        return false;
    },

    // ---- Job Status Polling ----

    pollJobStatus(jobId) {
        if (this.pollIntervals.has(jobId)) return;

        this.checkJobStatus(jobId);
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
            const resp = await fetch(`/jobs/${jobId}/status`, {
                headers: { 'Accept': 'application/json' }
            });
            if (!resp.ok) return;

            const data = await resp.json();
            this.updateJobDetailUI(jobId, data);

            const terminal = ['completed', 'failed', 'cancelled'];
            if (terminal.includes(data.status)) {
                this.stopPolling(jobId);
                if (data.status === 'completed') {
                    this.showToast('OCR processing completed!', 'success');
                    setTimeout(() => window.location.reload(), 1500);
                } else if (data.status === 'failed') {
                    this.showToast('OCR processing failed.', 'error');
                    setTimeout(() => window.location.reload(), 1500);
                }
            }
        } catch (err) {
            console.error('Poll error:', err);
        }
    },

    updateJobDetailUI(jobId, data) {
        const badge = document.getElementById('job-status-badge');
        if (badge) {
            badge.className = 'badge badge-' + data.status;
            badge.innerHTML = '<span class="badge-dot"></span> ' + this.capitalize(data.status);
        }

        const bar = document.getElementById('job-progress-bar');
        if (bar) {
            bar.style.width = (data.progress_percent || 0) + '%';
            if (data.status === 'completed') bar.className = 'progress-bar completed';
            else if (data.status === 'failed') bar.className = 'progress-bar failed';
        }

        const label = document.getElementById('progress-label');
        if (label) label.textContent = (data.progress_percent || 0) + '%';

        const pages = document.getElementById('pages-info');
        if (pages) {
            pages.textContent = (data.pages_processed || 0) + ' of ' + (data.pages_total || 0) + ' pages processed';
        }

        const statusBadge = document.getElementById('status-' + jobId);
        if (statusBadge) {
            statusBadge.className = 'badge badge-' + data.status;
            statusBadge.innerHTML = '<span class="badge-dot"></span> ' + this.capitalize(data.status);
        }

        const progBar = document.getElementById('progress-' + jobId);
        if (progBar) {
            progBar.style.width = (data.progress_percent || 0) + '%';
        }
    },

    // ---- Cancel Job ----

    cancelJob(jobId) {
        if (!confirm('Are you sure you want to cancel this job? This action cannot be undone.')) return;

        fetch(`/jobs/${jobId}/cancel`, {
            method: 'POST',
            headers: {
                'Accept': 'application/json',
                'X-Requested-With': 'XMLHttpRequest'
            }
        })
        .then(r => r.json())
        .then(data => {
            if (data.success) {
                this.showToast('Job cancelled.', 'success');
                this.stopPolling(jobId);
                setTimeout(() => {
                    window.location.href = data.redirect || '/jobs';
                }, 800);
            } else {
                this.showToast('Failed to cancel job.', 'error');
            }
        })
        .catch(() => this.showToast('Network error while cancelling.', 'error'));
    },

    // ---- Results Page ----

    showResultPage(pageIndex, tabEl) {
        document.querySelectorAll('.result-page-content').forEach(el => el.classList.add('hidden'));
        document.querySelectorAll('.page-tab').forEach(el => el.classList.remove('active'));

        const target = pageIndex === 'all'
            ? document.getElementById('result-all')
            : document.getElementById('result-' + pageIndex);

        if (target) target.classList.remove('hidden');
        if (tabEl) tabEl.classList.add('active');
    },

    copyResultText() {
        const block = document.getElementById('resultTextBlock');
        if (!block) return;

        navigator.clipboard.writeText(block.textContent).then(() => {
            this.showToast('Text copied to clipboard.', 'success');
        }).catch(() => {
            const range = document.createRange();
            range.selectNodeContents(block);
            const sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(range);
            document.execCommand('copy');
            sel.removeAllRanges();
            this.showToast('Text copied to clipboard.', 'success');
        });
    },

    // ---- Toast Notifications ----

    showToast(message, type) {
        type = type || 'info';
        const container = document.getElementById('toastContainer');
        if (!container) return;

        const toast = document.createElement('div');
        toast.className = 'toast';
        toast.style.borderLeft = '4px solid ' + this.toastColor(type);
        toast.innerHTML =
            '<span>' + this.escapeHtml(message) + '</span>' +
            '<button class="flash-close" onclick="this.parentElement.remove()" style="margin-left:auto">&times;</button>';

        container.appendChild(toast);

        setTimeout(() => {
            toast.classList.add('toast-out');
            setTimeout(() => toast.remove(), 250);
        }, 4500);
    },

    toastColor(type) {
        const map = { success: '#16a34a', error: '#dc2626', warning: '#d97706', info: '#2563eb' };
        return map[type] || map.info;
    },

    // ---- Flash Message Auto-Hide ----

    initFlashAutoHide() {
        document.querySelectorAll('.flash-message').forEach(el => {
            setTimeout(() => {
                el.style.opacity = '0';
                el.style.transform = 'translateY(-8px)';
                el.style.transition = 'all 0.3s ease';
                setTimeout(() => el.remove(), 300);
            }, 6000);
        });
    },

    // ---- Utilities ----

    formatFileSize(bytes) {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const units = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + units[i];
    },

    capitalize(str) {
        return str.charAt(0).toUpperCase() + str.slice(1);
    },

    escapeHtml(text) {
        const d = document.createElement('div');
        d.textContent = text;
        return d.innerHTML;
    }
};

document.addEventListener('DOMContentLoaded', () => OCRApp.init());
