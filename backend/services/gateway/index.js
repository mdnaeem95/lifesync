const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');

const app = express();

// Enable CORS for Flutter app
app.use(cors({
  origin: ['http://localhost:*', 'http://127.0.0.1:*'],
  credentials: true
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