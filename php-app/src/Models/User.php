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

    /**
     * @return array{id: int, sso_id: string, email: string, name: string, username: string, avatar: ?string}|null
     */
    public function findBySsoId(string $ssoId): ?array
    {
        $stmt = $this->db->prepare(
            'SELECT id, sso_id, email, name, username, avatar, created_at, updated_at 
             FROM users_local 
             WHERE sso_id = :sso_id 
             LIMIT 1'
        );
        $stmt->execute(['sso_id' => $ssoId]);

        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result !== false ? $result : null;
    }

    /**
     * @param array{sso_id: string, email: string, name: string, username: string, avatar?: ?string} $ssoData
     * @return array{id: int, sso_id: string, email: string, name: string, username: string, avatar: ?string}
     */
    public function createOrUpdate(array $ssoData): array
    {
        $existing = $this->findBySsoId($ssoData['sso_id']);

        if ($existing !== null) {
            $stmt = $this->db->prepare(
                'UPDATE users_local 
                 SET email = :email, name = :name, username = :username, avatar = :avatar, updated_at = NOW() 
                 WHERE sso_id = :sso_id 
                 RETURNING id, sso_id, email, name, username, avatar, created_at, updated_at'
            );
            $stmt->execute([
                'email'    => $ssoData['email'],
                'name'     => $ssoData['name'],
                'username' => $ssoData['username'],
                'avatar'   => $ssoData['avatar'] ?? null,
                'sso_id'   => $ssoData['sso_id'],
            ]);

            return $stmt->fetch(PDO::FETCH_ASSOC);
        }

        $stmt = $this->db->prepare(
            'INSERT INTO users_local (sso_id, email, name, username, avatar, created_at, updated_at) 
             VALUES (:sso_id, :email, :name, :username, :avatar, NOW(), NOW()) 
             RETURNING id, sso_id, email, name, username, avatar, created_at, updated_at'
        );
        $stmt->execute([
            'sso_id'   => $ssoData['sso_id'],
            'email'    => $ssoData['email'],
            'name'     => $ssoData['name'],
            'username' => $ssoData['username'],
            'avatar'   => $ssoData['avatar'] ?? null,
        ]);

        return $stmt->fetch(PDO::FETCH_ASSOC);
    }

    /**
     * @return array{id: int, sso_id: string, email: string, name: string, username: string, avatar: ?string}|null
     */
    public function findById(int $id): ?array
    {
        $stmt = $this->db->prepare(
            'SELECT id, sso_id, email, name, username, avatar, created_at, updated_at 
             FROM users_local 
             WHERE id = :id 
             LIMIT 1'
        );
        $stmt->execute(['id' => $id]);

        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result !== false ? $result : null;
    }
}
