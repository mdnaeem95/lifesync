package services_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/lifesync/flowtime/auth-service/internal/models"
	"github.com/lifesync/flowtime/auth-service/internal/services"
	"github.com/lifesync/flowtime/auth-service/pkg/logger"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

// Mock repository
type mockUserRepository struct {
	mock.Mock
}

func (m *mockUserRepository) Create(ctx context.Context, user *models.User) (*models.User, error) {
	args := m.Called(ctx, user)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*models.User), args.Error(1)
}

func (m *mockUserRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
	args := m.Called(ctx, email)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*models.User), args.Error(1)
}

// Add other mock methods...

// Mock JWT service
type mockJWTService struct {
	mock.Mock
}

func (m *mockJWTService) GenerateAccessToken(userID, email string) (string, error) {
	args := m.Called(userID, email)
	return args.String(0), args.Error(1)
}

func (m *mockJWTService) GenerateRefreshToken(userID string) (string, error) {
	args := m.Called(userID)
	return args.String(0), args.Error(1)
}

// Add other mock methods...

func TestAuthService_SignUp(t *testing.T) {
	ctx := context.Background()
	log := logger.New()

	t.Run("successful signup", func(t *testing.T) {
		// Arrange
		mockRepo := new(mockUserRepository)
		mockJWT := new(mockJWTService)
		authService := services.NewAuthService(mockRepo, mockJWT, log)

		req := models.SignUpRequest{
			Email:    "test@example.com",
			Password: "password123",
			Name:     "Test User",
		}

		// Mock repository expectations
		mockRepo.On("GetByEmail", ctx, req.Email).Return(nil, errors.New("not found"))
		mockRepo.On("Create", ctx, mock.AnythingOfType("*models.User")).Return(&models.User{
			ID:        "user-123",
			Email:     req.Email,
			Name:      req.Name,
			IsActive:  true,
			CreatedAt: time.Now(),
		}, nil)
		mockRepo.On("StoreRefreshToken", ctx, "user-123", mock.Anything, mock.Anything).Return(nil)

		// Mock JWT expectations
		mockJWT.On("GenerateAccessToken", "user-123", req.Email).Return("access-token", nil)
		mockJWT.On("GenerateRefreshToken", "user-123").Return("refresh-token", nil)

		// Act
		response, err := authService.SignUp(ctx, req)

		// Assert
		assert.NoError(t, err)
		assert.NotNil(t, response)
		assert.Equal(t, "access-token", response.AccessToken)
		assert.Equal(t, "refresh-token", response.RefreshToken)
		assert.Equal(t, req.Email, response.User.Email)

		mockRepo.AssertExpectations(t)
		mockJWT.AssertExpectations(t)
	})

	t.Run("user already exists", func(t *testing.T) {
		// Arrange
		mockRepo := new(mockUserRepository)
		mockJWT := new(mockJWTService)
		authService := services.NewAuthService(mockRepo, mockJWT, log)

		req := models.SignUpRequest{
			Email:    "existing@example.com",
			Password: "password123",
			Name:     "Existing User",
		}

		// Mock repository to return existing user
		mockRepo.On("GetByEmail", ctx, req.Email).Return(&models.User{
			ID:    "existing-user",
			Email: req.Email,
		}, nil)

		// Act
		response, err := authService.SignUp(ctx, req)

		// Assert
		assert.Error(t, err)
		assert.Nil(t, response)
		assert.Contains(t, err.Error(), "already exists")

		mockRepo.AssertExpectations(t)
	})
}

func TestAuthService_SignIn(t *testing.T) {
	ctx := context.Background()
	log := logger.New()

	t.Run("successful signin", func(t *testing.T) {
		// Test implementation...
	})

	t.Run("invalid credentials", func(t *testing.T) {
		// Test implementation...
	})

	t.Run("inactive user", func(t *testing.T) {
		// Test implementation...
	})
}
