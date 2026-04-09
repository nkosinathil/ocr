<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Create Account — OCR Platform</title>
    <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/app.css">
</head>
<body>
<div class="login-wrapper">
    <div class="login-card" style="max-width: 480px;">
        <div class="login-logo">O</div>
        <h1 class="login-title">Create Your Account</h1>
        <p class="login-subtitle">Start extracting text from documents in minutes. Free tier available.</p>

        <?php if (!empty($_SESSION['flash_error'])): ?>
            <div class="flash-message flash-error mb-3">
                <span>&#9888;</span>
                <?= htmlspecialchars($_SESSION['flash_error']) ?>
            </div>
            <?php unset($_SESSION['flash_error']); ?>
        <?php endif; ?>

        <?php if (!empty($_SESSION['flash_success'])): ?>
            <div class="flash-message flash-success mb-3">
                <span>&#10003;</span>
                <?= htmlspecialchars($_SESSION['flash_success']) ?>
            </div>
            <?php unset($_SESSION['flash_success']); ?>
        <?php endif; ?>

        <form action="/register" method="POST" style="text-align: left;">
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
                <div class="form-group">
                    <label class="form-label" for="first_name">First Name *</label>
                    <input type="text" name="first_name" id="first_name" class="form-input" required placeholder="Themba">
                </div>
                <div class="form-group">
                    <label class="form-label" for="last_name">Last Name</label>
                    <input type="text" name="last_name" id="last_name" class="form-input" placeholder="Nkosi">
                </div>
            </div>

            <div class="form-group">
                <label class="form-label" for="email">Work Email *</label>
                <input type="email" name="email" id="email" class="form-input" required placeholder="you@company.co.za">
            </div>

            <div class="form-group">
                <label class="form-label" for="company">Company / Organisation</label>
                <input type="text" name="company" id="company" class="form-input" placeholder="Your company name">
            </div>

            <button type="submit" class="btn btn-primary login-btn" style="margin-top: 8px;">
                Create Account
            </button>
        </form>

        <p style="margin-top: 20px; font-size: 13px; color: #6b7280;">
            Already have an account? <a href="/auth/login" style="font-weight: 500;">Sign in</a>
        </p>

        <div class="login-footer" style="margin-top: 16px;">
            <p>Your login details will be emailed to you.</p>
        </div>
    </div>
</div>
</body>
</html>
