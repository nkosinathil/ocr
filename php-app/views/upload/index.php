<?php
$title = 'Upload Document';
$maxSizeMB = round(($maxSize ?? 104857600) / 1048576);
$extensions = $allowedExtensions ?? ['pdf', 'jpg', 'jpeg', 'png', 'tiff', 'bmp', 'webp'];
?>

<div class="card">
    <div class="card-header">
        <div>
            <div class="card-title">Upload Document for OCR</div>
            <div class="card-subtitle">Supported formats: <?= strtoupper(implode(', ', $extensions)) ?> &mdash; Max size: <?= $maxSizeMB ?>MB</div>
        </div>
    </div>
    <div class="card-body">
        <form id="uploadForm" action="/upload" method="POST" enctype="multipart/form-data">
            <div class="upload-zone" id="uploadZone">
                <div class="upload-zone-icon">&#128196;</div>
                <div class="upload-zone-title">
                    Drag & drop your file here, or <span class="upload-zone-link">browse</span>
                </div>
                <div class="upload-zone-subtitle">
                    PDF, JPG, PNG, TIFF, BMP, WEBP up to <?= $maxSizeMB ?>MB
                </div>
                <input type="file"
                       name="document"
                       id="fileInput"
                       class="hidden"
                       accept=".pdf,.jpg,.jpeg,.png,.tiff,.tif,.bmp,.webp">
            </div>

            <div id="filePreview" class="hidden mt-3">
                <div class="card" style="border: 1px solid #e5e7eb;">
                    <div class="card-body d-flex align-center gap-2">
                        <div class="file-icon" id="fileTypeIcon">-</div>
                        <div class="flex-1">
                            <div class="font-medium" id="fileName">-</div>
                            <div class="text-sm text-muted" id="fileSize">-</div>
                        </div>
                        <button type="button" class="btn btn-ghost btn-sm" id="removeFile">&times; Remove</button>
                    </div>
                </div>
            </div>

            <div class="mt-3" style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
                <div class="form-group mb-0">
                    <label class="form-label" for="language">OCR Language</label>
                    <select name="language" id="language" class="form-select">
                        <option value="eng" selected>English</option>
                        <option value="afr">Afrikaans</option>
                        <option value="fra">French</option>
                        <option value="deu">German</option>
                        <option value="spa">Spanish</option>
                        <option value="ita">Italian</option>
                        <option value="por">Portuguese</option>
                        <option value="nld">Dutch</option>
                        <option value="rus">Russian</option>
                        <option value="chi_sim">Chinese (Simplified)</option>
                        <option value="jpn">Japanese</option>
                        <option value="kor">Korean</option>
                        <option value="ara">Arabic</option>
                    </select>
                </div>
                <div class="form-group mb-0">
                    <label class="form-label" for="engine">OCR Engine</label>
                    <select name="engine" id="engine" class="form-select">
                        <option value="tesseract" selected>Tesseract</option>
                    </select>
                </div>
            </div>

            <div class="d-flex gap-2 mt-3">
                <button type="submit" class="btn btn-primary btn-lg" id="submitBtn" disabled>
                    &#8682; Upload & Start OCR
                </button>
                <a href="/" class="btn btn-secondary btn-lg">Cancel</a>
            </div>

            <div id="uploadProgress" class="hidden mt-2">
                <div class="progress-bar-wrapper" style="height: 10px;">
                    <div class="progress-bar" id="progressBar" style="width: 0%"></div>
                </div>
                <div class="progress-text" id="progressText">Uploading... 0%</div>
            </div>
        </form>
    </div>
</div>
