package handlers

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/auth/models"
	"github.com/mdnaeem95/lifesync/backend/services/auth/services"
)

type AuthHandler struct {
	authService services.AuthService
	log         logger.Logger
	validator   *validator.Validate
}

func NewAuthHandler(authService services.AuthService, log logger.Logger) *AuthHandler {
	return &AuthHandler{
		authService: authService,
		log:         log,
		validator:   validator.New(),
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
			log.WithField("email", req.Email).Warn("User already exists")
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

	// Validate request
	if err := h.validator.Struct(req); err != nil {
		log.WithError(err).Warn("Refresh token validation failed")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation failed", "details": err.Error()})
		return
	}

	log.Info("Processing refresh token request")

	// Refresh tokens
	response, err := h.authService.RefreshToken(ctx, req.RefreshToken)
	if err != nil {
		log.WithError(err).Warn("Token refresh failed")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid refresh token"})
		return
	}

	log.Info("Tokens successfully refreshed")
	c.JSON(http.StatusOK, response)
}

// SignOut handles user logout
func (h *AuthHandler) SignOut(c *gin.Context) {
	ctx := c.Request.Context()
	log := h.log.WithContext(ctx)

	// Get user ID from context (set by auth middleware)
	userID, exists := c.Get("userID")
	if !exists {
		log.Error("User ID not found in context")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Authentication error"})
		return
	}

	var req models.SignOutRequest
	// Ignore error as refresh token is optional
	_ = c.ShouldBindJSON(&req)

	log.WithField("user_id", userID).Info("Processing signout request")

	// Sign out user
	if err := h.authService.SignOut(ctx, userID.(string), req.RefreshToken); err != nil {
		log.WithError(err).Warn("Signout failed")
		// Continue anyway - user should be signed out
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
		log.Warn("Missing verification token")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Verification token required"})
		return
	}

	log.Info("Processing email verification")

	if err := h.authService.VerifyEmail(ctx, token); err != nil {
		log.WithError(err).Warn("Email verification failed")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid or expired verification token"})
		return
	}

	log.Info("Email successfully verified")
	c.JSON(http.StatusOK, gin.H{"message": "Email verified successfully"})
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

	// Validate request
	if err := h.validator.Struct(req); err != nil {
		log.WithError(err).Warn("Password reset validation failed")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation failed", "details": err.Error()})
		return
	}

	log.WithField("email", req.Email).Info("Processing password reset request")

	if err := h.authService.RequestPasswordReset(ctx, req.Email); err != nil {
		log.WithError(err).Error("Password reset request failed")
		// Don't reveal if email exists or not
	}

	// Always return success to prevent email enumeration
	c.JSON(http.StatusOK, gin.H{"message": "If the email exists, a password reset link has been sent"})
}

// ResetPassword handles password reset with token
func (h *AuthHandler) ResetPassword(c *gin.Context) {
	ctx := c.Request.Context()
	log := h.log.WithContext(ctx)

	token := c.Param("token")
	if token == "" {
		log.Warn("Missing reset token")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Reset token required"})
		return
	}

	var req models.ResetPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid reset password request")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	// Validate request
	if err := h.validator.Struct(req); err != nil {
		log.WithError(err).Warn("Reset password validation failed")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation failed", "details": err.Error()})
		return
	}

	log.Info("Processing password reset")

	if err := h.authService.ResetPassword(ctx, token, req.NewPassword); err != nil {
		log.WithError(err).Warn("Password reset failed")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid or expired reset token"})
		return
	}

	log.Info("Password successfully reset")
	c.JSON(http.StatusOK, gin.H{"message": "Password reset successfully"})
}
