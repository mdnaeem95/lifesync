package services

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/auth/models"
	"github.com/mdnaeem95/lifesync/backend/services/auth/repository"
	"golang.org/x/crypto/bcrypt"
)

type AuthService interface {
	SignUp(ctx context.Context, req models.SignUpRequest) (*models.AuthResponse, error)
	SignIn(ctx context.Context, req models.SignInRequest) (*models.AuthResponse, error)
	RefreshToken(ctx context.Context, refreshToken string) (*models.TokenResponse, error)
	SignOut(ctx context.Context, userID, refreshToken string) error
	VerifyEmail(ctx context.Context, token string) error
	RequestPasswordReset(ctx context.Context, email string) error
	ResetPassword(ctx context.Context, token, newPassword string) error
}

type authService struct {
	userRepo   repository.UserRepository
	jwtService JWTService
	log        logger.Logger
}

func NewAuthService(userRepo repository.UserRepository, jwtService JWTService, log logger.Logger) AuthService {
	return &authService{
		userRepo:   userRepo,
		jwtService: jwtService,
		log:        log,
	}
}

func (s *authService) SignUp(ctx context.Context, req models.SignUpRequest) (*models.AuthResponse, error) {
	log := s.log.WithContext(ctx).WithField("operation", "signup")

	// Check if user already exists
	existingUser, err := s.userRepo.GetByEmail(ctx, req.Email)
	if err == nil && existingUser != nil {
		log.WithField("email", req.Email).Warn("User already exists")
		return nil, errors.New("user already exists")
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		log.WithError(err).Error("Failed to hash password")
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	// Create user
	user := &models.User{
		Email:        req.Email,
		Name:         req.Name,
		PasswordHash: string(hashedPassword),
		IsActive:     true,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	createdUser, err := s.userRepo.Create(ctx, user)
	if err != nil {
		log.WithError(err).Error("Failed to create user")
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	// Generate tokens
	accessToken, err := s.jwtService.GenerateAccessToken(createdUser.ID, createdUser.Email)
	if err != nil {
		log.WithError(err).Error("Failed to generate access token")
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	refreshToken, err := s.jwtService.GenerateRefreshToken(createdUser.ID)
	if err != nil {
		log.WithError(err).Error("Failed to generate refresh token")
		return nil, fmt.Errorf("failed to generate refresh token: %w", err)
	}

	// Store refresh token
	if err := s.userRepo.StoreRefreshToken(ctx, createdUser.ID, refreshToken, 30*24*time.Hour); err != nil {
		log.WithError(err).Error("Failed to store refresh token")
		return nil, fmt.Errorf("failed to store refresh token: %w", err)
	}

	log.WithField("user_id", createdUser.ID).Info("User successfully created")

	return &models.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    3600, // 1 hour in seconds
		User:         createdUser.ToPublicUser(),
	}, nil
}

func (s *authService) SignIn(ctx context.Context, req models.SignInRequest) (*models.AuthResponse, error) {
	log := s.log.WithContext(ctx).WithField("operation", "signin")

	// Get user by email
	user, err := s.userRepo.GetByEmail(ctx, req.Email)
	if err != nil {
		log.WithField("email", req.Email).Debug("User not found")
		return nil, errors.New("invalid credentials")
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		log.WithField("email", req.Email).Debug("Invalid password")
		return nil, errors.New("invalid credentials")
	}

	// Check if user is active
	if !user.IsActive {
		log.WithField("email", req.Email).Warn("Inactive user attempted to sign in")
		return nil, errors.New("account is inactive")
	}

	// Generate tokens
	accessToken, err := s.jwtService.GenerateAccessToken(user.ID, user.Email)
	if err != nil {
		log.WithError(err).Error("Failed to generate access token")
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	refreshToken, err := s.jwtService.GenerateRefreshToken(user.ID)
	if err != nil {
		log.WithError(err).Error("Failed to generate refresh token")
		return nil, fmt.Errorf("failed to generate refresh token: %w", err)
	}

	// Store refresh token
	if err := s.userRepo.StoreRefreshToken(ctx, user.ID, refreshToken, 30*24*time.Hour); err != nil {
		log.WithError(err).Error("Failed to store refresh token")
		return nil, fmt.Errorf("failed to store refresh token: %w", err)
	}

	// Update last login
	if err := s.userRepo.UpdateLastLogin(ctx, user.ID); err != nil {
		log.WithError(err).Warn("Failed to update last login")
		// Don't fail the login for this
	}

	log.WithField("user_id", user.ID).Info("User successfully signed in")

	return &models.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    3600, // 1 hour in seconds
		User:         user.ToPublicUser(),
	}, nil
}

func (s *authService) RefreshToken(ctx context.Context, refreshToken string) (*models.TokenResponse, error) {
	log := s.log.WithContext(ctx).WithField("operation", "refresh_token")

	// Validate refresh token
	claims, err := s.jwtService.ValidateRefreshToken(refreshToken)
	if err != nil {
		log.WithError(err).Debug("Invalid refresh token")
		return nil, errors.New("invalid refresh token")
	}

	// Check if refresh token is valid in database
	valid, err := s.userRepo.ValidateRefreshToken(ctx, claims.UserID, refreshToken)
	if err != nil || !valid {
		log.WithField("user_id", claims.UserID).Debug("Refresh token not found in database")
		return nil, errors.New("invalid refresh token")
	}

	// Get user
	user, err := s.userRepo.GetByID(ctx, claims.UserID)
	if err != nil {
		log.WithError(err).Error("Failed to get user")
		return nil, errors.New("user not found")
	}

	// Generate new tokens
	newAccessToken, err := s.jwtService.GenerateAccessToken(user.ID, user.Email)
	if err != nil {
		log.WithError(err).Error("Failed to generate new access token")
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	newRefreshToken, err := s.jwtService.GenerateRefreshToken(user.ID)
	if err != nil {
		log.WithError(err).Error("Failed to generate new refresh token")
		return nil, fmt.Errorf("failed to generate refresh token: %w", err)
	}

	// Revoke old refresh token
	if err := s.userRepo.RevokeRefreshToken(ctx, user.ID, refreshToken); err != nil {
		log.WithError(err).Warn("Failed to revoke old refresh token")
		// Continue anyway
	}

	// Store new refresh token
	if err := s.userRepo.StoreRefreshToken(ctx, user.ID, newRefreshToken, 30*24*time.Hour); err != nil {
		log.WithError(err).Error("Failed to store new refresh token")
		return nil, fmt.Errorf("failed to store refresh token: %w", err)
	}

	log.WithField("user_id", user.ID).Info("Tokens successfully refreshed")

	return &models.TokenResponse{
		AccessToken:  newAccessToken,
		RefreshToken: newRefreshToken,
		ExpiresIn:    3600, // 1 hour in seconds
	}, nil
}

func (s *authService) SignOut(ctx context.Context, userID, refreshToken string) error {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "signout",
		"user_id":   userID,
	})

	// Revoke the specific refresh token if provided
	if refreshToken != "" {
		if err := s.userRepo.RevokeRefreshToken(ctx, userID, refreshToken); err != nil {
			log.WithError(err).Warn("Failed to revoke refresh token")
			// Continue anyway
		}
	} else {
		// Revoke all refresh tokens for the user
		if err := s.userRepo.RevokeAllRefreshTokens(ctx, userID); err != nil {
			log.WithError(err).Warn("Failed to revoke all refresh tokens")
			// Continue anyway
		}
	}

	log.Info("User successfully signed out")
	return nil
}

func (s *authService) VerifyEmail(ctx context.Context, token string) error {
	log := s.log.WithContext(ctx).WithField("operation", "verify_email")

	// TODO: Implement email verification logic
	// This would typically:
	// 1. Validate the email verification token
	// 2. Mark the user's email as verified
	// 3. Delete the verification token

	log.Warn("Email verification not implemented")
	return errors.New("email verification not implemented")
}

func (s *authService) RequestPasswordReset(ctx context.Context, email string) error {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "request_password_reset",
		"email":     email,
	})

	// Get user by email
	user, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil {
		// Don't reveal if user exists or not
		log.WithField("email", email).Debug("User not found for password reset")
		return nil
	}

	// Generate reset token
	tokenBytes := make([]byte, 32)
	if _, err := rand.Read(tokenBytes); err != nil {
		log.WithError(err).Error("Failed to generate reset token")
		return fmt.Errorf("failed to generate reset token: %w", err)
	}
	resetToken := hex.EncodeToString(tokenBytes)

	// Store reset token with 1 hour expiry
	expiresAt := time.Now().Add(1 * time.Hour)
	if err := s.userRepo.StorePasswordResetToken(ctx, user.ID, resetToken, expiresAt); err != nil {
		log.WithError(err).Error("Failed to store reset token")
		return fmt.Errorf("failed to store reset token: %w", err)
	}

	// TODO: Send reset email
	// This would typically send an email with a link like:
	// https://app.flowtime.ai/reset-password?token=resetToken

	log.WithField("user_id", user.ID).Info("Password reset requested")
	return nil
}

func (s *authService) ResetPassword(ctx context.Context, token, newPassword string) error {
	log := s.log.WithContext(ctx).WithField("operation", "reset_password")

	// Validate reset token and get user ID
	userID, err := s.userRepo.ValidatePasswordResetToken(ctx, token)
	if err != nil {
		log.WithError(err).Debug("Invalid reset token")
		return errors.New("invalid or expired reset token")
	}

	// Hash new password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		log.WithError(err).Error("Failed to hash new password")
		return fmt.Errorf("failed to hash password: %w", err)
	}

	// Update password
	if err := s.userRepo.UpdatePassword(ctx, userID, string(hashedPassword)); err != nil {
		log.WithError(err).Error("Failed to update password")
		return fmt.Errorf("failed to update password: %w", err)
	}

	// Revoke all refresh tokens for security
	if err := s.userRepo.RevokeAllRefreshTokens(ctx, userID); err != nil {
		log.WithError(err).Warn("Failed to revoke refresh tokens after password reset")
		// Continue anyway
	}

	// Delete the used reset token
	if err := s.userRepo.DeletePasswordResetToken(ctx, token); err != nil {
		log.WithError(err).Warn("Failed to delete used reset token")
		// Continue anyway
	}

	log.WithField("user_id", userID).Info("Password successfully reset")
	return nil
}
