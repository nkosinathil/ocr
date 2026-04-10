<?php
use MxaOcr\Config\Auth;
use MxaOcr\Repositories\UserRepository;

$auth = Auth::getInstance();

// Verify state to prevent CSRF
if (!isset($_GET['state']) || !isset($_SESSION['oauth_state']) || $_GET['state'] !== $_SESSION['oauth_state']) {
    die('Invalid state parameter. Possible CSRF attack.');
}

// Clear the state
unset($_SESSION['oauth_state']);

// Exchange authorization code for tokens
$code = $_GET['code'] ?? null;
if (!$code) {
    die('No authorization code provided.');
}

$tokens = $auth->exchangeCodeForTokens($code);
if (!$tokens || !isset($tokens['access_token'])) {
    die('Failed to obtain access token.');
}

// Get user info from Keycloak
$userInfo = $auth->getUserInfo($tokens['access_token']);
if (!$userInfo) {
    die('Failed to get user information.');
}

// Parse ID token for roles
$idTokenData = $auth->parseToken($tokens['id_token']);
$roles = $idTokenData['resource_access'][$auth->get('client_id')]['roles'] ?? [];

// Merge user info with roles
$userInfo['roles'] = $roles;

// Create or update user in database
$userRepo = new UserRepository();
$user = $userRepo->createOrUpdate($userInfo);

// Store user info and tokens in session
$_SESSION['user_id'] = $user->id;
$_SESSION['keycloak_id'] = $user->keycloakId;
$_SESSION['email'] = $user->email;
$_SESSION['username'] = $user->username;
$_SESSION['full_name'] = $user->fullName;
$_SESSION['roles'] = $user->roles;
$_SESSION['access_token'] = $tokens['access_token'];
$_SESSION['refresh_token'] = $tokens['refresh_token'] ?? null;
$_SESSION['token_expires_at'] = time() + ($tokens['expires_in'] ?? 3600);

// Redirect to dashboard
header('Location: /dashboard');
exit;
