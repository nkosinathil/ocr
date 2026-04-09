<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= htmlspecialchars($title ?? 'OCR Platform') ?> — <?= htmlspecialchars($config['app']['name'] ?? 'OCR Platform') ?></title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;600;700&family=Roboto+Mono:wght@400;500&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/app.css">
</head>
<body>
    <div class="sidebar-overlay" id="sidebarOverlay"></div>

    <div class="app-wrapper">
        <?php
        $currentPath = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
        $currentPath = rtrim($currentPath, '/') ?: '/';
        ?>
        <aside class="sidebar" id="sidebar">
            <div class="sidebar-header">
                <div class="sidebar-logo">O</div>
                <div class="sidebar-brand">
                    OCR Platform
                    <small>Document Intelligence</small>
                </div>
            </div>

            <nav class="sidebar-nav">
                <div class="nav-section">
                    <div class="nav-section-title">Main</div>
                    <a href="/" class="nav-item <?= $currentPath === '/' ? 'active' : '' ?>">
                        <span class="nav-icon">&#9633;</span>
                        Dashboard
                    </a>
                    <a href="/upload" class="nav-item <?= $currentPath === '/upload' ? 'active' : '' ?>">
                        <span class="nav-icon">&#8682;</span>
                        Upload
                    </a>
                </div>
                <div class="nav-section">
                    <div class="nav-section-title">Processing</div>
                    <a href="/jobs" class="nav-item <?= str_starts_with($currentPath, '/jobs') ? 'active' : '' ?>">
                        <span class="nav-icon">&#9881;</span>
                        Jobs
                    </a>
                    <a href="/jobs?status=processing" class="nav-item">
                        <span class="nav-icon">&#8635;</span>
                        Active Jobs
                    </a>
                    <a href="/jobs?status=completed" class="nav-item">
                        <span class="nav-icon">&#10003;</span>
                        Completed
                    </a>
                </div>
            </nav>

            <?php if (isset($user)): ?>
            <div class="sidebar-footer">
                <div class="user-avatar">
                    <?= strtoupper(substr($user['display_name'] ?? $user['email'] ?? 'U', 0, 1)) ?>
                </div>
                <div class="user-info">
                    <div class="user-name"><?= htmlspecialchars($user['display_name'] ?? '') ?></div>
                    <div class="user-email"><?= htmlspecialchars($user['email'] ?? '') ?></div>
                </div>
                <a href="/auth/logout" class="btn btn-ghost btn-icon" title="Sign out">&#x2192;</a>
            </div>
            <?php endif; ?>
        </aside>

        <main class="main-content">
            <header class="topbar">
                <div class="topbar-left">
                    <button class="mobile-menu-toggle" id="menuToggle" aria-label="Toggle menu">&#9776;</button>
                    <h1 class="topbar-title"><?= htmlspecialchars($title ?? 'Dashboard') ?></h1>
                </div>
                <div class="topbar-right">
                    <a href="/upload" class="btn btn-primary btn-sm">&#8682; Upload File</a>
                </div>
            </header>

            <div class="page-body">
                <?php if (!empty($_SESSION['flash_success'])): ?>
                    <div class="flash-message flash-success">
                        <span>&#10003;</span>
                        <?= htmlspecialchars($_SESSION['flash_success']) ?>
                        <button class="flash-close" onclick="this.parentElement.remove()">&times;</button>
                    </div>
                    <?php unset($_SESSION['flash_success']); ?>
                <?php endif; ?>

                <?php if (!empty($_SESSION['flash_error'])): ?>
                    <div class="flash-message flash-error">
                        <span>&#9888;</span>
                        <?= htmlspecialchars($_SESSION['flash_error']) ?>
                        <button class="flash-close" onclick="this.parentElement.remove()">&times;</button>
                    </div>
                    <?php unset($_SESSION['flash_error']); ?>
                <?php endif; ?>

                <?php if (!empty($_SESSION['flash_warning'])): ?>
                    <div class="flash-message flash-warning">
                        <span>&#9888;</span>
                        <?= htmlspecialchars($_SESSION['flash_warning']) ?>
                        <button class="flash-close" onclick="this.parentElement.remove()">&times;</button>
                    </div>
                    <?php unset($_SESSION['flash_warning']); ?>
                <?php endif; ?>

                <?= $pageContent ?>
            </div>
        </main>
    </div>

    <div class="toast-container" id="toastContainer"></div>

    <script src="/assets/js/app.js"></script>
</body>
</html>
