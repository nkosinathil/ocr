<?php
declare(strict_types=1);

namespace MxaOcr\Models;

/**
 * User Model
 * 
 * Represents a user in the MXA OCR system.
 * Users are mapped from Keycloak SSO.
 */
class User
{
    public string $id;
    public string $keycloakId;
    public string $email;
    public string $username;
    public ?string $fullName;
    public array $roles;
    public bool $isActive;
    public string $createdAt;
    public string $updatedAt;
    public ?string $lastLoginAt;
    
    public function __construct(array $data)
    {
        $this->id = $data['id'] ?? '';
        $this->keycloak_id = $data['keycloak_id'] ?? '';
        $this->email = $data['email'] ?? '';
        $this->username = $data['username'] ?? '';
        $this->fullName = $data['full_name'] ?? null;
        $this->roles = isset($data['roles']) ? json_decode($data['roles'], true) : [];
        $this->isActive = $data['is_active'] ?? true;
        $this->createdAt = $data['created_at'] ?? '';
        $this->updatedAt = $data['updated_at'] ?? '';
        $this->lastLoginAt = $data['last_login_at'] ?? null;
    }
    
    /**
     * Check if user has a specific role
     */
    public function hasRole(string $role): bool
    {
        return in_array($role, $this->roles, true);
    }
    
    /**
     * Check if user has any of the specified roles
     */
    public function hasAnyRole(array $roles): bool
    {
        return !empty(array_intersect($this->roles, $roles));
    }
    
    /**
     * Check if user is admin
     */
    public function isAdmin(): bool
    {
        return $this->hasRole('ocr_admin');
    }
    
    /**
     * Convert to array
     */
    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'keycloak_id' => $this->keycloakId,
            'email' => $this->email,
            'username' => $this->username,
            'full_name' => $this->fullName,
            'roles' => $this->roles,
            'is_active' => $this->isActive,
            'created_at' => $this->createdAt,
            'updated_at' => $this->updatedAt,
            'last_login_at' => $this->lastLoginAt,
        ];
    }
}
