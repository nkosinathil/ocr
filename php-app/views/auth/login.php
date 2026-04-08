<div class="login-wrapper">
    <div class="login-card">
        <div class="login-logo">O</div>
        <h1 class="login-title">OCR Platform</h1>
        <p class="login-subtitle">Sign in with your organization account to access the document intelligence platform.</p>

        <?php if (!empty($_SESSION['flash_error'])): ?>
            <div class="flash-message flash-error mb-3">
                <span>&#9888;</span>
                <?= htmlspecialchars($_SESSION['flash_error']) ?>
            </div>
            <?php unset($_SESSION['flash_error']); ?>
        <?php endif; ?>

        <a href="/auth/login" class="btn btn-primary login-btn">
            &#128274; Sign in with SSO
        </a>

        <div class="login-footer">
            <p>Secured by enterprise single sign-on</p>
            <p class="mt-1">Protected by 192.168.1.59 Identity Server</p>
        </div>
    </div>
</div>
