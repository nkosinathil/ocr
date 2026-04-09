<?php

declare(strict_types=1);

namespace App\Models;

use App\Config\Database;
use PDO;

class User
{
    private PDO $db;

    public function __construct()
    {
        $this->db = Database::getInstance();
    }

    public function findBySsoId(string $ssoId): ?array
    {
        $stmt = $this->db->prepare(
            'SELECT id, sso_user_id, email, display_name, role, avatar_url,
                    last_login_at, is_active, created_at, updated_at
             FROM users_local
             WHERE sso_user_id = :sso_user_id
             LIMIT 1'
        );
        $stmt->execute(['sso_user_id' => $ssoId]);

        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result !== false ? $result : null;
    }

    public function createOrUpdate(array $ssoData): array
    {
        $existing = $this->findBySsoId($ssoData['sso_id']);

        if ($existing !== null) {
            $stmt = $this->db->prepare(
                'UPDATE users_local
                 SET email = :email, display_name = :display_name, avatar_url = :avatar_url,
                     last_login_at = NOW(), updated_at = NOW()
                 WHERE sso_user_id = :sso_user_id
                 RETURNING id, sso_user_id, email, display_name, role, avatar_url,
                           last_login_at, is_active, created_at, updated_at'
            );
            $stmt->execute([
                'email'        => $ssoData['email'],
                'display_name' => $ssoData['name'] ?? $ssoData['username'] ?? '',
                'avatar_url'   => $ssoData['avatar'] ?? null,
                'sso_user_id'  => $ssoData['sso_id'],
            ]);

            return $stmt->fetch(PDO::FETCH_ASSOC);
        }

        $stmt = $this->db->prepare(
            'INSERT INTO users_local (sso_user_id, email, display_name, avatar_url, last_login_at, created_at, updated_at)
             VALUES (:sso_user_id, :email, :display_name, :avatar_url, NOW(), NOW(), NOW())
             RETURNING id, sso_user_id, email, display_name, role, avatar_url,
                       last_login_at, is_active, created_at, updated_at'
        );
        $stmt->execute([
            'sso_user_id'  => $ssoData['sso_id'],
            'email'        => $ssoData['email'],
            'display_name' => $ssoData['name'] ?? $ssoData['username'] ?? '',
            'avatar_url'   => $ssoData['avatar'] ?? null,
        ]);

        return $stmt->fetch(PDO::FETCH_ASSOC);
    }

    public function findById(string $id): ?array
    {
        $stmt = $this->db->prepare(
            'SELECT id, sso_user_id, email, display_name, role, avatar_url,
                    last_login_at, is_active, created_at, updated_at
             FROM users_local
             WHERE id = :id
             LIMIT 1'
        );
        $stmt->execute(['id' => $id]);

        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result !== false ? $result : null;
    }
}
