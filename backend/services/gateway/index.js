const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();

// Manual CORS middleware - more control
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  res.header('Access-Control-Allow-Credentials', 'true');
  
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  
  next();
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'api-gateway' });
});

// Auth service proxy
const authProxy = createProxyMiddleware({
  target: process.env.AUTH_SERVICE_URL || 'http://auth-service:8080',
  changeOrigin: true,
  onProxyRes: function (proxyRes, req, res) {
    proxyRes.headers['Access-Control-Allow-Origin'] = '*';
  }
});

app.use('/auth', authProxy);

// FlowTime service proxy
const flowtimeProxy = createProxyMiddleware({
  target: process.env.FLOWTIME_SERVICE_URL || 'http://flowtime-service:3000',
  changeOrigin: true,
  pathRewrite: {
    '^/api/flowtime': ''
  },
  onProxyRes: function (proxyRes, req, res) {
    proxyRes.headers['Access-Control-Allow-Origin'] = '*';
  }
});

app.use('/api/flowtime', flowtimeProxy);

// Start server
const PORT = process.env.PORT || 8000;
app.listen(PORT, () => {
  console.log(`API Gateway listening on port ${PORT}`);
  console.log(`CORS enabled for all origins`);
});