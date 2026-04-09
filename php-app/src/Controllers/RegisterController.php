<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Services\SsoService;

class RegisterController
{
    private array $config;
    private SsoService $ssoService;

    public function __construct(array $config)
    {
        $this->config = $config;
        $this->ssoService = new SsoService($config['sso']);
    }

    public function index(): void
    {
        if (isset($_SESSION['user'])) {
            header('Location: /');
            exit;
        }

        $data = [
            'config' => $this->config,
            'title'  => 'Create Account',
        ];

        $this->render('auth/register', $data);
    }

    public function store(): void
    {
        $firstName = trim($_POST['first_name'] ?? '');
        $lastName  = trim($_POST['last_name'] ?? '');
        $email     = trim($_POST['email'] ?? '');
        $company   = trim($_POST['company'] ?? '');

        if ($email === '' || $firstName === '') {
            $_SESSION['flash_error'] = 'First name and email are required.';
            header('Location: /register');
            exit;
        }

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $_SESSION['flash_error'] = 'Please enter a valid email address.';
            header('Location: /register');
            exit;
        }

        try {
            $password = $this->generatePassword();

            $adminToken = $this->getKeycloakAdminToken();

            $username = strtolower(explode('@', $email)[0]);
            $username = preg_replace('/[^a-z0-9._-]/', '', $username);

            $this->createKeycloakUser($adminToken, [
                'username'  => $username,
                'email'     => $email,
                'firstName' => $firstName,
                'lastName'  => $lastName,
                'enabled'   => true,
                'credentials' => [[
                    'type'      => 'password',
                    'value'     => $password,
                    'temporary' => false,
                ]],
                'attributes' => [
                    'company' => [$company],
                    'tier'    => ['free'],
                ],
            ]);

            $this->sendWelcomeEmail($email, $firstName, $username, $password);

            $_SESSION['flash_success'] = 'Account created! Login details have been sent to ' . htmlspecialchars($email);
            header('Location: /auth/login');
            exit;
        } catch (\Throwable $e) {
            error_log('Registration error: ' . $e->getMessage());

            if (str_contains($e->getMessage(), '409') || str_contains(strtolower($e->getMessage()), 'exists')) {
                $_SESSION['flash_error'] = 'An account with this email already exists. Please sign in instead.';
            } else {
                $_SESSION['flash_error'] = 'Registration failed. Please try again or contact support.';
            }
            header('Location: /register');
            exit;
        }
    }

    private function getKeycloakAdminToken(): string
    {
        $url = $this->config['sso']['server_url'] . '/realms/master/protocol/openid-connect/token';

        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL            => $url,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => http_build_query([
                'grant_type' => 'client_credentials',
                'client_id'  => $this->config['sso']['client_id'],
                'client_secret' => $this->config['sso']['client_secret'],
            ]),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 10,
            CURLOPT_HTTPHEADER     => ['Content-Type: application/x-www-form-urlencoded'],
            CURLOPT_SSL_VERIFYPEER => false,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        $data = json_decode($response, true);

        if ($httpCode !== 200 || empty($data['access_token'])) {
            throw new \RuntimeException('Failed to obtain Keycloak admin token (HTTP ' . $httpCode . ')');
        }

        return $data['access_token'];
    }

    private function createKeycloakUser(string $token, array $userData): void
    {
        $realm = $this->config['sso']['realm'] ?? 'gint';
        $url = $this->config['sso']['server_url'] . '/admin/realms/' . $realm . '/users';

        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL            => $url,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => json_encode($userData),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 10,
            CURLOPT_HTTPHEADER     => [
                'Authorization: Bearer ' . $token,
                'Content-Type: application/json',
            ],
            CURLOPT_SSL_VERIFYPEER => false,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($httpCode !== 201) {
            throw new \RuntimeException('Keycloak user creation failed (HTTP ' . $httpCode . '): ' . $response);
        }
    }

    private function sendWelcomeEmail(string $email, string $firstName, string $username, string $password): void
    {
        $appName = $this->config['app']['name'] ?? 'OCR Platform';
        $appUrl  = $this->config['app']['url'] ?? 'http://192.168.1.66';

        $subject = "Welcome to {$appName} - Your Login Details";

        $body = "Hi {$firstName},\n\n";
        $body .= "Your account on {$appName} has been created successfully.\n\n";
        $body .= "=== Your Login Details ===\n";
        $body .= "Platform URL: {$appUrl}\n";
        $body .= "Username:     {$username}\n";
        $body .= "Password:     {$password}\n\n";
        $body .= "Please sign in and change your password after first login.\n\n";
        $body .= "=== What you can do ===\n";
        $body .= "- Upload scanned PDFs and images\n";
        $body .= "- Extract text using OCR (English, Afrikaans + 10 other languages)\n";
        $body .= "- Monitor processing in real-time\n";
        $body .= "- Download extracted text\n\n";
        $body .= "For support, contact your administrator.\n\n";
        $body .= "Regards,\n{$appName} Team\n";

        $headers = [
            'From: noreply@' . parse_url($appUrl, PHP_URL_HOST),
            'Reply-To: noreply@' . parse_url($appUrl, PHP_URL_HOST),
            'Content-Type: text/plain; charset=UTF-8',
            'X-Mailer: OCR-Platform/1.0',
        ];

        $sent = @mail($email, $subject, $body, implode("\r\n", $headers));

        if (!$sent) {
            error_log("Failed to send welcome email to {$email} — mail() returned false. User: {$username}, Pass: {$password}");
        }
    }

    private function generatePassword(int $length = 12): string
    {
        $upper  = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
        $lower  = 'abcdefghjkmnpqrstuvwxyz';
        $digits = '23456789';
        $special = '!@#$%&*';

        $password = $upper[random_int(0, strlen($upper) - 1)]
                  . $lower[random_int(0, strlen($lower) - 1)]
                  . $digits[random_int(0, strlen($digits) - 1)]
                  . $special[random_int(0, strlen($special) - 1)];

        $all = $upper . $lower . $digits . $special;
        for ($i = strlen($password); $i < $length; $i++) {
            $password .= $all[random_int(0, strlen($all) - 1)];
        }

        return str_shuffle($password);
    }

    private function render(string $view, array $data = []): void
    {
        extract($data);
        $content = BASE_PATH . '/views/' . $view . '.php';

        ob_start();
        if (file_exists($content)) {
            require $content;
        }
        $pageContent = ob_get_clean();

        echo $pageContent;
    }
}
