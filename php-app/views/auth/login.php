<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sign In — OCR Platform</title>
    <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/app.css">
</head>
<body>
<div class="login-wrapper">
    <div class="login-card">
        <div class="login-logo">O</div>
        <h1 class="login-title">OCR Platform</h1>
        <p class="login-subtitle">Enterprise document intelligence. Extract text from scanned PDFs and images with precision.</p>

        <?php if (!empty($_SESSION['flash_error'])): ?>
            <div class="flash-message flash-error mb-3" style="text-align: left;">
                <span>&#9888;</span>
                <?= htmlspecialchars($_SESSION['flash_error']) ?>
            </div>
            <?php unset($_SESSION['flash_error']); ?>
        <?php endif; ?>

        <?php if (!empty($_SESSION['flash_success'])): ?>
            <div class="flash-message flash-success mb-3" style="text-align: left;">
                <span>&#10003;</span>
                <?= htmlspecialchars($_SESSION['flash_success']) ?>
            </div>
            <?php unset($_SESSION['flash_success']); ?>
        <?php endif; ?>

        <a href="/auth/sso" class="btn btn-primary login-btn">
            Sign in with SSO
        </a>

        <div style="margin: 24px 0; display: flex; align-items: center; gap: 12px;">
            <div style="flex: 1; height: 1px; background: #e5e7eb;"></div>
            <span style="font-size: 12px; color: #9ca3af; text-transform: uppercase; letter-spacing: 1px;">or</span>
            <div style="flex: 1; height: 1px; background: #e5e7eb;"></div>
        </div>

        <a href="/register" class="btn btn-secondary login-btn">
            Create a Free Account
        </a>

        <p style="margin-top: 16px; font-size: 13px; color: #6b7280;">
            <a href="/pricing" style="font-weight: 500;">View Pricing Plans</a>
        </p>

        <div class="login-footer">
            <p>Secured by enterprise single sign-on</p>
        </div>
    </div>
</div>
</body>
</html>
