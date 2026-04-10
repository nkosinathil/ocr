<?php
declare(strict_types=1);

namespace MxaOcr\Repositories;

use MxaOcr\Config\Database;
use MxaOcr\Models\User;

/**
 * User Repository
 * 
 * Data access layer for users table.
 */
class UserRepository
{
    /**
     * Find user by ID
     */
    public function findById(string $id): ?User
    {
        $sql = "SELECT * FROM users WHERE id = :id LIMIT 1";
        $result = Database::queryOne($sql, ['id' => $id]);
        
        return $result ? new User($result) : null;
    }
    
    /**
     * Find user by Keycloak ID
     */
    public function findByKeycloakId(string $keycloakId): ?User
    {
        $sql = "SELECT * FROM users WHERE keycloak_id = :keycloak_id LIMIT 1";
        $result = Database::queryOne($sql, ['keycloak_id' => $keycloakId]);
        
        return $result ? new User($result) : null;
    }
    
    /**
     * Find user by email
     */
    public function findByEmail(string $email): ?User
    {
        $sql = "SELECT * FROM users WHERE email = :email LIMIT 1";
        $result = Database::queryOne($sql, ['email' => $email]);
        
        return $result ? new User($result) : null;
    }
    
    /**
     * Create new user from Keycloak data
     */
    public function create(array $data): User
    {
        $sql = "INSERT INTO users (keycloak_id, email, username, full_name, roles, is_active)
                VALUES (:keycloak_id, :email, :username, :full_name, :roles, :is_active)
                RETURNING *";
        
        $params = [
            'keycloak_id' => $data['keycloak_id'],
            'email' => $data['email'],
            'username' => $data['username'] ?? $data['email'],
            'full_name' => $data['full_name'] ?? null,
            'roles' => json_encode($data['roles'] ?? []),
            'is_active' => $data['is_active'] ?? true,
        ];
        
        $result = Database::queryOne($sql, $params);
        return new User($result);
    }
    
    /**
     * Update user
     */
    public function update(string $id, array $data): bool
    {
        $fields = [];
        $params = ['id' => $id];
        
        if (isset($data['email'])) {
            $fields[] = 'email = :email';
            $params['email'] = $data['email'];
        }
        if (isset($data['username'])) {
            $fields[] = 'username = :username';
            $params['username'] = $data['username'];
        }
        if (isset($data['full_name'])) {
            $fields[] = 'full_name = :full_name';
            $params['full_name'] = $data['full_name'];
        }
        if (isset($data['roles'])) {
            $fields[] = 'roles = :roles';
            $params['roles'] = json_encode($data['roles']);
        }
        if (isset($data['is_active'])) {
            $fields[] = 'is_active = :is_active';
            $params['is_active'] = $data['is_active'];
        }
        
        if (empty($fields)) {
            return false;
        }
        
        $sql = "UPDATE users SET " . implode(', ', $fields) . " WHERE id = :id";
        return Database::execute($sql, $params) > 0;
    }
    
    /**
     * Update last login time
     */
    public function updateLastLogin(string $id): bool
    {
        $sql = "UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = :id";
        return Database::execute($sql, ['id' => $id]) > 0;
    }
    
    /**
     * Create or update user from Keycloak
     */
    public function createOrUpdate(array $keycloakData): User
    {
        $user = $this->findByKeycloakId($keycloakData['sub']);
        
        $userData = [
            'keycloak_id' => $keycloakData['sub'],
            'email' => $keycloakData['email'] ?? '',
            'username' => $keycloakData['preferred_username'] ?? $keycloakData['email'] ?? '',
            'full_name' => $keycloakData['name'] ?? null,
            'roles' => $keycloakData['roles'] ?? [],
        ];
        
        if ($user) {
            $this->update($user->id, $userData);
            $this->updateLastLogin($user->id);
            return $this->findById($user->id);
        }
        
        return $this->create($userData);
    }
    
    /**
     * Get all active users
     */
    public function getAllActive(): array
    {
        $sql = "SELECT * FROM users WHERE is_active = true ORDER BY created_at DESC";
        $results = Database::query($sql);
        
        return array_map(fn($row) => new User($row), $results);
    }
}
