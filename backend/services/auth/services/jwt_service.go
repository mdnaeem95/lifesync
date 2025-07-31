package services

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
)

type JWTService interface {
	GenerateAccessToken(userID, email string) (string, error)
	GenerateRefreshToken(userID string) (string, error)
	ValidateAccessToken(token string) (*AccessTokenClaims, error)
	ValidateRefreshToken(token string) (*RefreshTokenClaims, error)
}

type jwtService struct {
	secret string
	log    logger.Logger
}

type AccessTokenClaims struct {
	UserID string `json:"user_id"`
	Email  string `json:"email"`
	Type   string `json:"type"`
	jwt.RegisteredClaims
}

type RefreshTokenClaims struct {
	UserID string `json:"user_id"`
	Type   string `json:"type"`
	jwt.RegisteredClaims
}

func NewJWTService(secret string, log logger.Logger) JWTService {
	return &jwtService{
		secret: secret,
		log:    log,
	}
}

func (s *jwtService) GenerateAccessToken(userID, email string) (string, error) {
	log := s.log.WithField("operation", "generate_access_token")

	claims := AccessTokenClaims{
		UserID: userID,
		Email:  email,
		Type:   "access",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(1 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "flowtime-auth",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(s.secret))
	if err != nil {
		log.WithError(err).Error("Failed to sign access token")
		return "", fmt.Errorf("failed to sign token: %w", err)
	}

	log.WithField("user_id", userID).Debug("Access token generated")
	return tokenString, nil
}

func (s *jwtService) GenerateRefreshToken(userID string) (string, error) {
	log := s.log.WithField("operation", "generate_refresh_token")

	claims := RefreshTokenClaims{
		UserID: userID,
		Type:   "refresh",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(30 * 24 * time.Hour)), // 30 days
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "flowtime-auth",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(s.secret))
	if err != nil {
		log.WithError(err).Error("Failed to sign refresh token")
		return "", fmt.Errorf("failed to sign token: %w", err)
	}

	log.WithField("user_id", userID).Debug("Refresh token generated")
	return tokenString, nil
}

func (s *jwtService) ValidateAccessToken(tokenString string) (*AccessTokenClaims, error) {
	log := s.log.WithField("operation", "validate_access_token")

	token, err := jwt.ParseWithClaims(tokenString, &AccessTokenClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(s.secret), nil
	})

	if err != nil {
		log.WithError(err).Debug("Failed to parse access token")
		return nil, err
	}

	claims, ok := token.Claims.(*AccessTokenClaims)
	if !ok || !token.Valid {
		log.Debug("Invalid access token claims")
		return nil, errors.New("invalid token")
	}

	if claims.Type != "access" {
		log.Debug("Wrong token type")
		return nil, errors.New("invalid token type")
	}

	return claims, nil
}

func (s *jwtService) ValidateRefreshToken(tokenString string) (*RefreshTokenClaims, error) {
	log := s.log.WithField("operation", "validate_refresh_token")

	token, err := jwt.ParseWithClaims(tokenString, &RefreshTokenClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(s.secret), nil
	})

	if err != nil {
		log.WithError(err).Debug("Failed to parse refresh token")
		return nil, err
	}

	claims, ok := token.Claims.(*RefreshTokenClaims)
	if !ok || !token.Valid {
		log.Debug("Invalid refresh token claims")
		return nil, errors.New("invalid token")
	}

	if claims.Type != "refresh" {
		log.Debug("Wrong token type")
		return nil, errors.New("invalid token type")
	}

	return claims, nil
}
