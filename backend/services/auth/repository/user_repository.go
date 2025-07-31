package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/auth/models"
)

type UserRepository interface {
	Create(ctx context.Context, user *models.User) (*models.User, error)
	GetByID(ctx context.Context, id string) (*models.User, error)
	GetByEmail(ctx context.Context, email string) (*models.User, error)
	UpdateLastLogin(ctx context.Context, userID string) error
	UpdatePassword(ctx context.Context, userID, passwordHash string) error
	MarkEmailVerified(ctx context.Context, userID string) error

	// Refresh token management
	StoreRefreshToken(ctx context.Context, userID, token string, expiresIn time.Duration) error
	ValidateRefreshToken(ctx context.Context, userID, token string) (bool, error)
	RevokeRefreshToken(ctx context.Context, userID, token string) error
	RevokeAllRefreshTokens(ctx context.Context, userID string) error

	// Password reset
	StorePasswordResetToken(ctx context.Context, userID, token string, expiresAt time.Time) error
	ValidatePasswordResetToken(ctx context.Context, token string) (string, error)
	DeletePasswordResetToken(ctx context.Context, token string) error
}

type userRepository struct {
	db  *sql.DB
	log logger.Logger
}

func NewUserRepository(db *sql.DB, log logger.Logger) UserRepository {
	return &userRepository{
		db:  db,
		log: log,
	}
}

func (r *userRepository) Create(ctx context.Context, user *models.User) (*models.User, error) {
	log := r.log.WithContext(ctx).WithField("operation", "create_user")

	user.ID = uuid.New().String()

	query := `
		INSERT INTO users (id, email, password_hash, name, photo_url, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, created_at, updated_at
	`

	err := r.db.QueryRowContext(
		ctx,
		query,
		user.ID,
		user.Email,
		user.PasswordHash,
		user.Name,
		user.PhotoURL,
		user.IsActive,
		user.CreatedAt,
		user.UpdatedAt,
	).Scan(&user.ID, &user.CreatedAt, &user.UpdatedAt)

	if err != nil {
		log.WithError(err).Error("Failed to create user")
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	log.WithField("user_id", user.ID).Info("User created in database")
	return user, nil
}

func (r *userRepository) GetByID(ctx context.Context, id string) (*models.User, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_user_by_id",
		"user_id":   id,
	})

	var user models.User
	query := `
		SELECT id, email, password_hash, name, photo_url, is_active, created_at, updated_at
		FROM users
		WHERE id = $1
	`

	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.Name,
		&user.PhotoURL,
		&user.IsActive,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		log.Debug("User not found")
		return nil, errors.New("user not found")
	}
	if err != nil {
		log.WithError(err).Error("Failed to get user")
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return &user, nil
}

func (r *userRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_user_by_email",
		"email":     email,
	})

	var user models.User
	query := `
		SELECT id, email, password_hash, name, photo_url, is_active, created_at, updated_at
		FROM users
		WHERE email = $1
	`

	err := r.db.QueryRowContext(ctx, query, email).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.Name,
		&user.PhotoURL,
		&user.IsActive,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		log.Debug("User not found")
		return nil, errors.New("user not found")
	}
	if err != nil {
		log.WithError(err).Error("Failed to get user")
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return &user, nil
}

func (r *userRepository) UpdateLastLogin(ctx context.Context, userID string) error {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "update_last_login",
		"user_id":   userID,
	})

	query := `
		UPDATE users 
		SET updated_at = $1 
		WHERE id = $2
	`

	_, err := r.db.ExecContext(ctx, query, time.Now(), userID)
	if err != nil {
		log.WithError(err).Error("Failed to update last login")
		return fmt.Errorf("failed to update last login: %w", err)
	}

	return nil
}

func (r *userRepository) UpdatePassword(ctx context.Context, userID, passwordHash string) error {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "update_password",
		"user_id":   userID,
	})

	query := `
		UPDATE users 
		SET password_hash = $1, updated_at = $2 
		WHERE id = $3
	`

	_, err := r.db.ExecContext(ctx, query, passwordHash, time.Now(), userID)
	if err != nil {
		log.WithError(err).Error("Failed to update password")
		return fmt.Errorf("failed to update password: %w", err)
	}

	return nil
}

func (r *userRepository) MarkEmailVerified(ctx context.Context, userID string) error {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "mark_email_verified",
		"user_id":   userID,
	})

	query := `
		UPDATE users 
		SET email_verified = true, updated_at = $1 
		WHERE id = $2
	`

	_, err := r.db.ExecContext(ctx, query, time.Now(), userID)
	if err != nil {
		log.WithError(err).Error("Failed to mark email as verified")
		return fmt.Errorf("failed to mark email as verified: %w", err)
	}

	return nil
}

// Refresh Token Management

func (r *userRepository) StoreRefreshToken(ctx context.Context, userID, token string, expiresIn time.Duration) error {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "store_refresh_token",
		"user_id":   userID,
	})

	expiresAt := time.Now().Add(expiresIn)
	query := `
		INSERT INTO refresh_tokens (id, user_id, token, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5)
	`

	_, err := r.db.ExecContext(
		ctx,
		query,
		uuid.New().String(),
		userID,
		token,
		expiresAt,
		time.Now(),
	)

	if err != nil {
		log.WithError(err).Error("Failed to store refresh token")
		return fmt.Errorf("failed to store refresh token: %w", err)
	}

	return nil
}

func (r *userRepository) ValidateRefreshToken(ctx context.Context, userID, token string) (bool, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "validate_refresh_token",
		"user_id":   userID,
	})

	var count int
	query := `
		SELECT COUNT(*) 
		FROM refresh_tokens 
		WHERE user_id = $1 
		AND token = $2 
		AND expires_at > $3 
		AND revoked_at IS NULL
	`

	err := r.db.QueryRowContext(ctx, query, userID, token, time.Now()).Scan(&count)
	if err != nil {
		log.WithError(err).Error("Failed to validate refresh token")
		return false, fmt.Errorf("failed to validate refresh token: %w", err)
	}

	return count > 0, nil
}

func (r *userRepository) RevokeRefreshToken(ctx context.Context, userID, token string) error {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "revoke_refresh_token",
		"user_id":   userID,
	})

	query := `
		UPDATE refresh_tokens 
		SET revoked_at = $1 
		WHERE user_id = $2 
		AND token = $3 
		AND revoked_at IS NULL
	`

	_, err := r.db.ExecContext(ctx, query, time.Now(), userID, token)
	if err != nil {
		log.WithError(err).Error("Failed to revoke refresh token")
		return fmt.Errorf("failed to revoke refresh token: %w", err)
	}

	return nil
}

func (r *userRepository) RevokeAllRefreshTokens(ctx context.Context, userID string) error {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "revoke_all_refresh_tokens",
		"user_id":   userID,
	})

	query := `
		UPDATE refresh_tokens 
		SET revoked_at = $1 
		WHERE user_id = $2 
		AND revoked_at IS NULL
	`

	_, err := r.db.ExecContext(ctx, query, time.Now(), userID)
	if err != nil {
		log.WithError(err).Error("Failed to revoke all refresh tokens")
		return fmt.Errorf("failed to revoke all refresh tokens: %w", err)
	}

	return nil
}

// Password Reset

func (r *userRepository) StorePasswordResetToken(ctx context.Context, userID, token string, expiresAt time.Time) error {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "store_password_reset_token",
		"user_id":   userID,
	})

	query := `
		INSERT INTO password_reset_tokens (id, user_id, token, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (user_id) 
		DO UPDATE SET token = $3, expires_at = $4, created_at = $5
	`

	_, err := r.db.ExecContext(
		ctx,
		query,
		uuid.New().String(),
		userID,
		token,
		expiresAt,
		time.Now(),
	)

	if err != nil {
		log.WithError(err).Error("Failed to store password reset token")
		return fmt.Errorf("failed to store password reset token: %w", err)
	}

	return nil
}

func (r *userRepository) ValidatePasswordResetToken(ctx context.Context, token string) (string, error) {
	log := r.log.WithContext(ctx).WithField("operation", "validate_password_reset_token")

	var userID string
	query := `
		SELECT user_id 
		FROM password_reset_tokens 
		WHERE token = $1 
		AND expires_at > $2 
		AND used_at IS NULL
	`

	err := r.db.QueryRowContext(ctx, query, token, time.Now()).Scan(&userID)
	if err == sql.ErrNoRows {
		log.Debug("Password reset token not found or expired")
		return "", errors.New("invalid or expired token")
	}
	if err != nil {
		log.WithError(err).Error("Failed to validate password reset token")
		return "", fmt.Errorf("failed to validate token: %w", err)
	}

	// Mark token as used
	updateQuery := `
		UPDATE password_reset_tokens 
		SET used_at = $1 
		WHERE token = $2
	`
	_, _ = r.db.ExecContext(ctx, updateQuery, time.Now(), token)

	return userID, nil
}

func (r *userRepository) DeletePasswordResetToken(ctx context.Context, token string) error {
	log := r.log.WithContext(ctx).WithField("operation", "delete_password_reset_token")

	query := `
		DELETE FROM password_reset_tokens 
		WHERE token = $1
	`

	_, err := r.db.ExecContext(ctx, query, token)
	if err != nil {
		log.WithError(err).Error("Failed to delete password reset token")
		return fmt.Errorf("failed to delete token: %w", err)
	}

	return nil
}
