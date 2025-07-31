package handlers

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/lifesync/flowtime/auth-service/internal/models"
	"github.com/lifesync/flowtime/auth-service/internal/services"
	"github.com/lifesync/flowtime/auth-service/pkg/logger"
)

type AuthHandler struct {
	authService services.AuthService
	validator   *validator.Validate
	log         logger.Logger
}

func NewAuthHandler(authService services.AuthService, log logger.Logger) *AuthHandler {
	return &AuthHandler{
		authService: authService,
		validator:   validator.New(),
		log:         log,
	}
}

// SignUp handles user registration
func (h *AuthHandler) SignUp(c *gin.Context) {
	ctx := c.Request.Context()
	log := h.log.WithContext(ctx)

	var req models.SignUpRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid signup request")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	// Validate request
	if err := h.validator.Struct(req); err != nil {
		log.WithError(err).Warn("Signup validation failed")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation failed", "details": err.Error()})
		return
	}

	log.WithField("email", req.Email).Info("Processing signup request")

	// Create user
	response, err := h.authService.SignUp(ctx, req)
	if err != nil {
		if strings.Contains(err.Error(), "already exists") {
			log.WithField("email", req.Email).Warn("Signup failed: user already exists")
			c.JSON(http.StatusConflict, gin.H{"error": "User already exists"})
			return
		}
		log.WithError(err).Error("Signup failed")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
		return
	}

	log.WithFields(map[string]interface{}{
		"user_id": response.User.ID,
		"email":   response.User.Email,
	}).Info("User successfully created")

	c.JSON(http.StatusCreated, response)
}

// SignIn handles user login
func (h *AuthHandler) SignIn(c *gin.Context) {
	ctx := c.Request.Context()
	log := h.log.WithContext(ctx)

	var req models.SignInRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid signin request")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	// Validate request
	if err := h.validator.Struct(req); err != nil {
		log.WithError(err).Warn("Signin validation failed")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation failed", "details": err.Error()})
		return
	}

	log.WithField("email", req.Email).Info("Processing signin request")

	// Authenticate user
	response, err := h.authService.SignIn(ctx, req)
	if err != nil {
		if strings.Contains(err.Error(), "invalid credentials") {
			log.WithField("email", req.Email).Warn("Signin failed: invalid credentials")
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
			return
		}
		log.WithError(err).Error("Signin failed")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Authentication failed"})
		return
	}

	log.WithFields(map[string]interface{}{
		"user_id": response.User.ID,
		"email":   response.User.Email,
	}).Info("User successfully authenticated")

	c.JSON(http.StatusOK, response)
}

// RefreshToken handles token refresh
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	ctx := c.Request.Context()
	log := h.log.WithContext(ctx)

	var req models.RefreshTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid refresh token request")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	log.Info("Processing refresh token request")

	// Refresh tokens
	response, err := h.authService.RefreshToken(ctx, req.RefreshToken)
	if err != nil {
		if strings.Contains(err.Error(), "invalid") || strings.Contains(err.Error(), "expired") {
			log.Warn("Refresh token failed: invalid or expired token")
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired refresh token"})
			return
		}
		log.WithError(err).Error("Refresh token failed")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to refresh token"})
		return
	}

	log.Info("Token successfully refreshed")
	c.JSON(http.StatusOK, response)
}

// SignOut handles user logout
func (h *AuthHandler) SignOut(c *gin.Context) {
	ctx := c.Request.Context()
	log := h.log.WithContext(ctx)

	// Get user ID from context (set by auth middleware)
	userID, exists := c.Get("user_id")
	if !exists {
		log.Error("User ID not found in context")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal error"})
		return
	}

	log.WithField("user_id", userID).Info("Processing signout request")

	// Get refresh token from request
	var req models.SignOutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		// Sign out without refresh token (just invalidate access token)
		log.WithField("user_id", userID).Info("User signed out (no refresh token)")
		c.JSON(http.StatusOK, gin.H{"message": "Successfully signed out"})
		return
	}

	// Invalidate refresh token
	if err := h.authService.SignOut(ctx, userID.(string), req.RefreshToken); err != nil {
		log.WithError(err).Error("Failed to invalidate refresh token")
		// Still return success as the user is effectively logged out
	}

	log.WithField("user_id", userID).Info("User successfully signed out")
	c.JSON(http.StatusOK, gin.H{"message": "Successfully signed out"})
}

// VerifyEmail handles email verification
func (h *AuthHandler) VerifyEmail(c *gin.Context) {
	ctx := c.Request.Context()
	log := h.log.WithContext(ctx)

	token := c.Param("token")
	if token == "" {
		log.Warn("Email verification failed: missing token")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Missing verification token"})
		return
	}

	log.WithField("token", token[:10]+"...").Info("Processing email verification")

	if err := h.authService.VerifyEmail(ctx, token); err != nil {
		if strings.Contains(err.Error(), "invalid") || strings.Contains(err.Error(), "expired") {
			log.Warn("Email verification failed: invalid or expired token")
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid or expired verification token"})
			return
		}
		log.WithError(err).Error("Email verification failed")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify email"})
		return
	}

	log.Info("Email successfully verified")
	c.JSON(http.StatusOK, gin.H{"message": "Email successfully verified"})
}

// RequestPasswordReset handles password reset requests
func (h *AuthHandler) RequestPasswordReset(c *gin.Context) {
	ctx := c.Request.Context()
	log := h.log.WithContext(ctx)

	var req models.PasswordResetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid password reset request")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	log.WithField("email", req.Email).Info("Processing password reset request")

	// Always return success to prevent email enumeration
	if err := h.authService.RequestPasswordReset(ctx, req.Email); err != nil {
		log.WithError(err).Error("Password reset request failed")
	}

	c.JSON(http.StatusOK, gin.H{"message": "If the email exists, a password reset link has been sent"})
}

// ResetPassword handles password reset with token
func (h *AuthHandler) ResetPassword(c *gin.Context) {
	ctx := c.Request.Context()
	log := h.log.WithContext(ctx)

	token := c.Param("token")
	if token == "" {
		log.Warn("Password reset failed: missing token")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Missing reset token"})
		return
	}

	var req models.ResetPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid reset password request")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	log.WithField("token", token[:10]+"...").Info("Processing password reset")

	if err := h.authService.ResetPassword(ctx, token, req.NewPassword); err != nil {
		if strings.Contains(err.Error(), "invalid") || strings.Contains(err.Error(), "expired") {
			log.Warn("Password reset failed: invalid or expired token")
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid or expired reset token"})
			return
		}
		log.WithError(err).Error("Password reset failed")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reset password"})
		return
	}

	log.Info("Password successfully reset")
	c.JSON(http.StatusOK, gin.H{"message": "Password successfully reset"})
}
