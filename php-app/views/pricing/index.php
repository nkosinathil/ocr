<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pricing — OCR Platform</title>
    <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/app.css">
    <style>
        .pricing-page { min-height: 100vh; background: #ffffff; }
        .pricing-nav { padding: 20px 40px; display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #f3f4f6; }
        .pricing-nav-brand { display: flex; align-items: center; gap: 10px; }
        .pricing-nav-brand .sidebar-logo { width: 32px; height: 32px; font-size: 14px; }
        .pricing-nav-brand span { font-size: 16px; font-weight: 600; color: #111827; }
        .pricing-nav-links { display: flex; align-items: center; gap: 24px; }
        .pricing-nav-links a { font-size: 14px; color: #4b5563; font-weight: 450; }
        .pricing-nav-links a:hover { color: #111827; }
        .pricing-hero { text-align: center; padding: 80px 20px 40px; }
        .pricing-hero h1 { font-size: 40px; font-weight: 700; color: #111827; letter-spacing: -1px; margin-bottom: 16px; }
        .pricing-hero p { font-size: 18px; color: #6b7280; max-width: 600px; margin: 0 auto; line-height: 1.6; }
        .pricing-toggle { display: flex; align-items: center; justify-content: center; gap: 12px; margin: 32px 0; }
        .pricing-toggle span { font-size: 14px; color: #6b7280; font-weight: 450; }
        .pricing-toggle .active-toggle { color: #111827; font-weight: 600; }
        .pricing-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px; max-width: 1080px; margin: 0 auto; padding: 0 20px 80px; }
        .pricing-card { background: #ffffff; border: 1px solid #e5e7eb; border-radius: 16px; padding: 40px 32px; position: relative; transition: box-shadow 0.2s ease, transform 0.2s ease; }
        .pricing-card:hover { box-shadow: 0 8px 32px rgba(0,0,0,0.06); transform: translateY(-2px); }
        .pricing-card.featured { border: 2px solid #111827; }
        .pricing-badge { position: absolute; top: -12px; left: 50%; transform: translateX(-50%); background: #111827; color: #fff; font-size: 11px; font-weight: 600; padding: 4px 16px; border-radius: 20px; letter-spacing: 0.5px; text-transform: uppercase; }
        .pricing-tier { font-size: 14px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px; color: #6b7280; margin-bottom: 8px; }
        .pricing-price { font-size: 48px; font-weight: 700; color: #111827; letter-spacing: -2px; line-height: 1.1; }
        .pricing-price small { font-size: 16px; font-weight: 400; color: #9ca3af; letter-spacing: 0; }
        .pricing-desc { font-size: 14px; color: #6b7280; margin: 12px 0 28px; line-height: 1.5; }
        .pricing-features { list-style: none; padding: 0; margin: 0 0 32px; }
        .pricing-features li { font-size: 14px; color: #374151; padding: 8px 0; display: flex; align-items: flex-start; gap: 10px; line-height: 1.4; }
        .pricing-features li::before { content: "✓"; color: #111827; font-weight: 700; flex-shrink: 0; margin-top: 1px; }
        .pricing-cta { width: 100%; padding: 14px; font-size: 15px; }
        .pricing-card.featured .pricing-cta { background: #111827; border-color: #111827; }
        .pricing-card.featured .pricing-cta:hover { background: #374151; }
        .pricing-footer { text-align: center; padding: 40px 20px; border-top: 1px solid #f3f4f6; background: #fafbfc; }
        .pricing-footer p { font-size: 14px; color: #6b7280; }
        .pricing-faq { max-width: 700px; margin: 0 auto; padding: 60px 20px; }
        .pricing-faq h2 { font-size: 28px; font-weight: 700; color: #111827; text-align: center; margin-bottom: 40px; }
        .faq-item { border-bottom: 1px solid #e5e7eb; padding: 20px 0; }
        .faq-q { font-size: 15px; font-weight: 600; color: #111827; margin-bottom: 8px; }
        .faq-a { font-size: 14px; color: #6b7280; line-height: 1.6; }
        @media (max-width: 768px) {
            .pricing-grid { grid-template-columns: 1fr; max-width: 400px; }
            .pricing-hero h1 { font-size: 28px; }
            .pricing-nav { padding: 16px 20px; }
        }
    </style>
</head>
<body>
<div class="pricing-page">
    <nav class="pricing-nav">
        <div class="pricing-nav-brand">
            <div class="sidebar-logo">O</div>
            <span>OCR Platform</span>
        </div>
        <div class="pricing-nav-links">
            <a href="/auth/login">Sign In</a>
            <a href="/register" class="btn btn-primary btn-sm">Get Started</a>
        </div>
    </nav>

    <div class="pricing-hero">
        <h1>Simple, transparent pricing</h1>
        <p>Extract text from scanned documents with enterprise-grade OCR. Start free, scale as you grow. All prices in South African Rands.</p>
    </div>

    <div class="pricing-grid">
        <!-- FREE TIER -->
        <div class="pricing-card">
            <div class="pricing-tier">Starter</div>
            <div class="pricing-price">R0 <small>/month</small></div>
            <div class="pricing-desc">For individuals exploring OCR. Get started without commitment.</div>
            <ul class="pricing-features">
                <li>25 pages per month</li>
                <li>5 documents per month</li>
                <li>Max 5MB per file</li>
                <li>English &amp; Afrikaans OCR</li>
                <li>PDF &amp; image support</li>
                <li>Text download (TXT)</li>
                <li>Community support</li>
            </ul>
            <a href="/register" class="btn btn-secondary pricing-cta">Start Free</a>
        </div>

        <!-- PROFESSIONAL TIER -->
        <div class="pricing-card featured">
            <div class="pricing-badge">Most Popular</div>
            <div class="pricing-tier">Professional</div>
            <div class="pricing-price">R499 <small>/month</small></div>
            <div class="pricing-desc">For professionals and small teams handling regular document volumes.</div>
            <ul class="pricing-features">
                <li>500 pages per month</li>
                <li>100 documents per month</li>
                <li>Max 50MB per file</li>
                <li>All 13 languages supported</li>
                <li>Priority processing queue</li>
                <li>Bulk upload</li>
                <li>Download as TXT &amp; PDF</li>
                <li>Email support (24h response)</li>
                <li>Job history &amp; analytics</li>
            </ul>
            <a href="/register" class="btn btn-primary pricing-cta">Start 14-Day Free Trial</a>
        </div>

        <!-- ENTERPRISE TIER -->
        <div class="pricing-card">
            <div class="pricing-tier">Enterprise</div>
            <div class="pricing-price">R2,499 <small>/month</small></div>
            <div class="pricing-desc">For organisations with high-volume document processing needs.</div>
            <ul class="pricing-features">
                <li>Unlimited pages</li>
                <li>Unlimited documents</li>
                <li>Max 100MB per file</li>
                <li>All 13 languages + custom</li>
                <li>Dedicated processing queue</li>
                <li>API access for integration</li>
                <li>SSO / SAML integration</li>
                <li>Multi-user team management</li>
                <li>Custom export formats</li>
                <li>Dedicated account manager</li>
                <li>SLA with 99.9% uptime</li>
                <li>On-premise deployment option</li>
            </ul>
            <a href="/register" class="btn btn-secondary pricing-cta">Contact Sales</a>
        </div>
    </div>

    <div class="pricing-faq">
        <h2>Frequently Asked Questions</h2>

        <div class="faq-item">
            <div class="faq-q">What file formats are supported?</div>
            <div class="faq-a">We support scanned PDFs, JPG, JPEG, PNG, TIFF, BMP, and WebP image formats. Multi-page PDF documents are processed page by page with individual confidence scores.</div>
        </div>

        <div class="faq-item">
            <div class="faq-q">Which languages can be extracted?</div>
            <div class="faq-a">We support 13 languages including English, Afrikaans, French, German, Spanish, Italian, Portuguese, Dutch, Russian, Chinese (Simplified), Japanese, Korean, and Arabic. Enterprise plans can add custom language packs.</div>
        </div>

        <div class="faq-item">
            <div class="faq-q">How accurate is the OCR?</div>
            <div class="faq-a">Our Tesseract-powered engine achieves 95–99% accuracy on clean scans. Each result includes per-page confidence scores so you know exactly how reliable the extraction is. Image preprocessing (contrast, sharpening) is applied automatically.</div>
        </div>

        <div class="faq-item">
            <div class="faq-q">Is my data secure?</div>
            <div class="faq-a">Yes. Documents are stored in private object storage (never publicly accessible), processed in isolated workers, and accessible only through authenticated sessions. Enterprise plans include SSO integration and on-premise deployment.</div>
        </div>

        <div class="faq-item">
            <div class="faq-q">Can I cancel or change plans anytime?</div>
            <div class="faq-a">Absolutely. You can upgrade, downgrade, or cancel your plan at any time. Changes take effect at the start of your next billing cycle. No long-term contracts required.</div>
        </div>

        <div class="faq-item">
            <div class="faq-q">Do you offer annual billing?</div>
            <div class="faq-a">Yes. Annual billing gives you 2 months free — Professional at R4,990/year (save R998) and Enterprise at R24,990/year (save R4,998). Contact us for annual pricing.</div>
        </div>
    </div>

    <div class="pricing-footer">
        <p>Need a custom plan or volume pricing? <a href="mailto:sales@gint.co.za" style="font-weight: 500;">Contact our sales team</a></p>
        <p style="margin-top: 8px; font-size: 12px; color: #9ca3af;">All prices exclude VAT (15%). &copy; <?= date('Y') ?> OCR Platform. Powered by GI.</p>
    </div>
</div>
</body>
</html>
