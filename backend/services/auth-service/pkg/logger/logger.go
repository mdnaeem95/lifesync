package logger

import (
	"context"
	"os"
	"time"

	"github.com/sirupsen/logrus"
)

type Logger interface {
	Debug(msg string)
	Info(msg string)
	Warn(msg string)
	Error(msg string)
	Fatal(msg string)

	WithField(key string, value interface{}) Logger
	WithFields(fields map[string]interface{}) Logger
	WithError(err error) Logger
	WithContext(ctx context.Context) Logger
}

type logrusLogger struct {
	logger *logrus.Entry
}

func New() Logger {
	log := logrus.New()

	// Set JSON formatter
	log.SetFormatter(&logrus.JSONFormatter{
		TimestampFormat: time.RFC3339,
		FieldMap: logrus.FieldMap{
			logrus.FieldKeyTime:  "timestamp",
			logrus.FieldKeyLevel: "level",
			logrus.FieldKeyMsg:   "message",
		},
	})

	// Set output
	log.SetOutput(os.Stdout)

	// Set log level from environment
	level := os.Getenv("LOG_LEVEL")
	switch level {
	case "debug":
		log.SetLevel(logrus.DebugLevel)
	case "warn":
		log.SetLevel(logrus.WarnLevel)
	case "error":
		log.SetLevel(logrus.ErrorLevel)
	default:
		log.SetLevel(logrus.InfoLevel)
	}

	// Add default fields
	entry := log.WithFields(logrus.Fields{
		"service": "auth-service",
		"version": os.Getenv("SERVICE_VERSION"),
	})

	return &logrusLogger{logger: entry}
}

func (l *logrusLogger) Debug(msg string) {
	l.logger.Debug(msg)
}

func (l *logrusLogger) Info(msg string) {
	l.logger.Info(msg)
}

func (l *logrusLogger) Warn(msg string) {
	l.logger.Warn(msg)
}

func (l *logrusLogger) Error(msg string) {
	l.logger.Error(msg)
}

func (l *logrusLogger) Fatal(msg string) {
	l.logger.Fatal(msg)
}

func (l *logrusLogger) WithField(key string, value interface{}) Logger {
	return &logrusLogger{logger: l.logger.WithField(key, value)}
}

func (l *logrusLogger) WithFields(fields map[string]interface{}) Logger {
	return &logrusLogger{logger: l.logger.WithFields(fields)}
}

func (l *logrusLogger) WithError(err error) Logger {
	return &logrusLogger{logger: l.logger.WithError(err)}
}

func (l *logrusLogger) WithContext(ctx context.Context) Logger {
	// Extract request ID from context if available
	if requestID := ctx.Value("request_id"); requestID != nil {
		return &logrusLogger{logger: l.logger.WithField("request_id", requestID)}
	}
	return l
}
