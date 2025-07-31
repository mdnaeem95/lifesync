package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/lifesync/flowtime/auth-service/internal/models"
	"github.com/lifesync/flowtime/auth-service/internal/repository"
	"github.com/lifesync/flowtime/auth-service/pkg/logger"
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

	log.WithField("user_id", createdUser.ID).Info("User created successfully")

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
		// Continue anyway - user is created
	}

	// TODO: Send verification email
	// s.emailService.SendVerificationEmail(createdUser.Email, verificationToken)

	return &models.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    3600, // 1 hour
		User:         createdUser.ToPublicUser(),
	}, nil
}

func (s *authService) SignIn(ctx context.Context, req models.SignInRequest) (*models.AuthResponse, error) {
	log := s.log.WithContext(ctx).WithField("operation", "signin")

	// Get user by email
	user, err := s.userRepo.GetByEmail(ctx, req.Email)
	if err != nil {
		log.WithField("email", req.Email).Warn("User not found")
		return nil, errors.New("invalid credentials")
	}

	// Check password
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		log.WithField("user_id", user.ID).Warn("Invalid password")
		return nil, errors.New("invalid credentials")
	}

	// Check if user is active
	if !user.IsActive {
		log.WithField("user_id", user.ID).Warn("Inactive user attempting to sign in")
		return nil, errors.New("account is inactive")
	}

	log.WithField("user_id", user.ID).Info("User authenticated successfully")

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
		// Continue anyway
	}

	// Update last login
	if err := s.userRepo.UpdateLastLogin(ctx, user.ID); err != nil {
		log.WithError(err).Warn("Failed to update last login")
		// Non-critical error
	}

	return &models.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    3600, // 1 hour
		User:         user.ToPublicUser(),
	}, nil
}

func (s *authService) RefreshToken(ctx context.Context, refreshToken string) (*models.TokenResponse, error) {
	log := s.log.WithContext(ctx).WithField("operation", "refresh_token")

	// Validate refresh token
	claims, err := s.jwtService.ValidateRefreshToken(refreshToken)
	if err != nil {
		log.WithError(err).Warn("Invalid refresh token")
		return nil, errors.New("invalid refresh token")
	}

	// Check if token is stored (not revoked)
	valid, err := s.userRepo.ValidateRefreshToken(ctx, claims.UserID, refreshToken)
	if err != nil || !valid {
		log.WithField("user_id", claims.UserID).Warn("Refresh token not found or revoked")
		return nil, errors.New("invalid refresh token")
	}

	// Get user to ensure they still exist and are active
	user, err := s.userRepo.GetByID(ctx, claims.UserID)
	if err != nil || !user.IsActive {
		log.WithField("user_id", claims.UserID).Warn("User not found or inactive")
		return nil, errors.New("invalid refresh token")
	}

	log.WithField("user_id", user.ID).Info("Generating new tokens")

	// Generate new access token
	newAccessToken, err := s.jwtService.GenerateAccessToken(user.ID, user.Email)
	if err != nil {
		log.WithError(err).Error("Failed to generate new access token")
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	// Generate new refresh token
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
		// Continue anyway
	}

	return &models.TokenResponse{
		AccessToken:  newAccessToken,
		RefreshToken: newRefreshToken,
		ExpiresIn:    3600, // 1 hour
	}, nil
}

func (s *authService) SignOut(ctx context.Context, userID, refreshToken string) error {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "signout",
		"user_id":   userID,
	})

	// Revoke refresh token if provided
	if refreshToken != "" {
		if err := s.userRepo.RevokeRefreshToken(ctx, userID, refreshToken); err != nil {
			log.WithError(err).Warn("Failed to revoke refresh token")
			// Continue anyway - user is still logged out
		}
	}

	// Could also blacklist the access token here if needed
	// s.tokenBlacklist.Add(accessToken)

	log.Info("User signed out successfully")
	return nil
}

func (s *authService) VerifyEmail(ctx context.Context, token string) error {
	log := s.log.WithContext(ctx).WithField("operation", "verify_email")

	// Validate verification token
	// TODO: Implement token validation logic
	userID := "" // Extract from token

	// Mark email as verified
	if err := s.userRepo.MarkEmailVerified(ctx, userID); err != nil {
		log.WithError(err).Error("Failed to mark email as verified")
		return fmt.Errorf("failed to verify email: %w", err)
	}

	log.WithField("user_id", userID).Info("Email verified successfully")
	return nil
}

func (s *authService) RequestPasswordReset(ctx context.Context, email string) error {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "request_password_reset",
		"email":     email,
	})

	// Get user by email
	user, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil {
		// Don't reveal if email exists
		log.WithField("email", email).Info("Password reset requested for non-existent email")
		return nil
	}

	// Generate reset token
	resetToken := generateSecureToken()
	expiresAt := time.Now().Add(1 * time.Hour)

	// Store reset token
	if err := s.userRepo.StorePasswordResetToken(ctx, user.ID, resetToken, expiresAt); err != nil {
		log.WithError(err).Error("Failed to store password reset token")
		return fmt.Errorf("failed to process password reset: %w", err)
	}

	// TODO: Send password reset email
	// s.emailService.SendPasswordResetEmail(user.Email, resetToken)

	log.WithField("user_id", user.ID).Info("Password reset email sent")
	return nil
}

func (s *authService) ResetPassword(ctx context.Context, token, newPassword string) error {
	log := s.log.WithContext(ctx).WithField("operation", "reset_password")

	// Validate reset token
	userID, err := s.userRepo.ValidatePasswordResetToken(ctx, token)
	if err != nil {
		log.Warn("Invalid or expired password reset token")
		return errors.New("invalid or expired reset token")
	}

	// Hash new password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		log.WithError(err).Error("Failed to hash password")
		return fmt.Errorf("failed to hash password: %w", err)
	}

	// Update password
	if err := s.userRepo.UpdatePassword(ctx, userID, string(hashedPassword)); err != nil {
		log.WithError(err).Error("Failed to update password")
		return fmt.Errorf("failed to update password: %w", err)
	}

	// Revoke all refresh tokens for security
	if err := s.userRepo.RevokeAllRefreshTokens(ctx, userID); err != nil {
		log.WithError(err).Warn("Failed to revoke refresh tokens")
		// Continue anyway
	}

	// Delete reset token
	if err := s.userRepo.DeletePasswordResetToken(ctx, token); err != nil {
		log.WithError(err).Warn("Failed to delete reset token")
		// Continue anyway
	}

	log.WithField("user_id", userID).Info("Password reset successfully")
	return nil
}

func generateSecureToken() string {
	// TODO: Implement secure token generation
	return "secure_random_token"
}
