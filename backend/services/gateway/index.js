const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');

const app = express();

// Enable CORS for Flutter app - Fixed configuration
app.use(cors({
  origin: function(origin, callback) {
    // Allow requests with no origin (like mobile apps or Postman)
    if (!origin) return callback(null, true);
    
    // List of allowed origins
    const allowedOrigins = [
      'http://localhost:3000',
      'http://localhost:8080',
      'http://localhost:50000',
      'http://localhost:50001',
      'http://localhost:50002',
      'http://localhost:50003',
      'http://localhost:50004',
      'http://localhost:50005',
      'http://127.0.0.1:3000',
      'http://127.0.0.1:8080',
      'http://127.0.0.1:50000',
      'http://127.0.0.1:50001',
      'http://127.0.0.1:50002',
      'http://127.0.0.1:50003',
      'http://127.0.0.1:50004',
      'http://127.0.0.1:50005',
    ];
    
    // Check if the origin is in the allowed list
    if (allowedOrigins.indexOf(origin) !== -1 || origin.match(/^http:\/\/localhost:\d+$/)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'api-gateway' });
});

// Auth service proxy
app.use('/auth', createProxyMiddleware({
  target: process.env.AUTH_SERVICE_URL || 'http://auth-service:8080',
  changeOrigin: true,
  onError: (err, req, res) => {
    console.error('Auth proxy error:', err);
    res.status(502).json({ error: 'Auth service unavailable' });
  }
}));

// FlowTime service proxy
app.use('/api/flowtime', createProxyMiddleware({
  target: process.env.FLOWTIME_SERVICE_URL || 'http://flowtime-service:3000',
  changeOrigin: true,
  pathRewrite: {
    '^/api/flowtime': ''
  },
  onError: (err, req, res) => {
    console.error('FlowTime proxy error:', err);
    res.status(502).json({ error: 'FlowTime service unavailable' });
  }
}));

// Error handling
app.use((err, req, res, next) => {
  console.error('Gateway error:', err);
  res.status(500).json({ error: 'Internal gateway error' });
});

// Start server
const PORT = process.env.PORT || 8000;
app.listen(PORT, () => {
  console.log(`API Gateway listening on port ${PORT}`);
  console.log(`Auth service: ${process.env.AUTH_SERVICE_URL || 'http://auth-service:8080'}`);
  console.log(`FlowTime service: ${process.env.FLOWTIME_SERVICE_URL || 'http://flowtime-service:3000'}`);
});