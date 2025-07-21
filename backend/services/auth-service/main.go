package main

import (
    "context"
    "database/sql"
    "encoding/json"
    "log"
    "net/http"
    "os"
    "time"

    "github.com/gorilla/mux"
    "github.com/golang-jwt/jwt/v5"
    _ "github.com/lib/pq"
    "golang.org/x/crypto/bcrypt"
)

type AuthService struct {
    db *sql.DB
    jwtSecret []byte
}

type User struct {
    ID        string    `json:"id"`
    Email     string    `json:"email"`
    Name      string    `json:"name"`
    PhotoURL  string    `json:"photo_url,omitempty"`
    CreatedAt time.Time `json:"created_at"`
}

type SignUpRequest struct {
    Email    string `json:"email"`
    Password string `json:"password"`
    Name     string `json:"name"`
}

type SignInRequest struct {
    Email    string `json:"email"`
    Password string `json:"password"`
}

type TokenResponse struct {
    AccessToken  string `json:"access_token"`
    RefreshToken string `json:"refresh_token"`
    ExpiresIn    int    `json:"expires_in"`
    User         User   `json:"user"`
}

func NewAuthService(db *sql.DB, jwtSecret string) *AuthService {
    return &AuthService{
        db:        db,
        jwtSecret: []byte(jwtSecret),
    }
}

func (s *AuthService) SignUp(w http.ResponseWriter, r *http.Request) {
    var req SignUpRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "Invalid request", http.StatusBadRequest)
        return
    }

    // Hash password
    hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
    if err != nil {
        http.Error(w, "Internal server error", http.StatusInternalServerError)
        return
    }

    // Create user
    var user User
    err = s.db.QueryRow(`
        INSERT INTO users (email, password_hash, name, created_at)
        VALUES ($1, $2, $3, $4)
        RETURNING id, email, name, created_at
    `, req.Email, hashedPassword, req.Name, time.Now()).Scan(
        &user.ID, &user.Email, &user.Name, &user.CreatedAt,
    )

    if err != nil {
        if err.Error() == "pq: duplicate key value violates unique constraint" {
            http.Error(w, "Email already exists", http.StatusConflict)
            return
        }
        http.Error(w, "Internal server error", http.StatusInternalServerError)
        return
    }

    // Generate tokens
    tokens, err := s.generateTokens(user.ID)
    if err != nil {
        http.Error(w, "Internal server error", http.StatusInternalServerError)
        return
    }

    // Send response
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(TokenResponse{
        AccessToken:  tokens.AccessToken,
        RefreshToken: tokens.RefreshToken,
        ExpiresIn:    3600,
        User:         user,
    })

    // Publish user created event
    publishUserCreatedEvent(user)
}

func (s *AuthService) SignIn(w http.ResponseWriter, r *http.Request) {
    var req SignInRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "Invalid request", http.StatusBadRequest)
        return
    }

    // Get user
    var user User
    var passwordHash string
    err := s.db.QueryRow(`
        SELECT id, email, name, photo_url, created_at, password_hash
        FROM users WHERE email = $1
    `, req.Email).Scan(
        &user.ID, &user.Email, &user.Name, &user.PhotoURL, 
        &user.CreatedAt, &passwordHash,
    )

    if err == sql.ErrNoRows {
        http.Error(w, "Invalid credentials", http.StatusUnauthorized)
        return
    }

    // Verify password
    if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)); err != nil {
        http.Error(w, "Invalid credentials", http.StatusUnauthorized)
        return
    }

    // Generate tokens
    tokens, err := s.generateTokens(user.ID)
    if err != nil {
        http.Error(w, "Internal server error", http.StatusInternalServerError)
        return
    }

    // Send response
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(TokenResponse{
        AccessToken:  tokens.AccessToken,
        RefreshToken: tokens.RefreshToken,
        ExpiresIn:    3600,
        User:         user,
    })
}

func (s *AuthService) generateTokens(userID string) (*TokenResponse, error) {
    // Access token - expires in 1 hour
    accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
        "user_id": userID,
        "exp":     time.Now().Add(time.Hour).Unix(),
        "type":    "access",
    })

    accessTokenString, err := accessToken.SignedString(s.jwtSecret)
    if err != nil {
        return nil, err
    }

    // Refresh token - expires in 30 days
    refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
        "user_id": userID,
        "exp":     time.Now().Add(time.Hour * 24 * 30).Unix(),
        "type":    "refresh",
    })

    refreshTokenString, err := refreshToken.SignedString(s.jwtSecret)
    if err != nil {
        return nil, err
    }

    return &TokenResponse{
        AccessToken:  accessTokenString,
        RefreshToken: refreshTokenString,
    }, nil
}

func main() {
    // Database connection
    db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        log.Fatal("Failed to connect to database:", err)
    }
    defer db.Close()

    // Create service
    authService := NewAuthService(db, os.Getenv("JWT_SECRET"))

    // Setup routes
    router := mux.NewRouter()
    router.HandleFunc("/auth/signup", authService.SignUp).Methods("POST")
    router.HandleFunc("/auth/signin", authService.SignIn).Methods("POST")
    
    // Health check
    router.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    })

    // Start server
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }

    log.Printf("Auth service listening on port %s", port)
    log.Fatal(http.ListenAndServe(":"+port, router))
}

func publishUserCreatedEvent(user User) {
    // TODO: Implement Kafka/RabbitMQ publishing
    log.Printf("User created event: %+v", user)
}