const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'test-server' });
});

app.post('/auth/signup', (req, res) => {
  console.log('Signup request:', req.body);
  res.json({
    user: {
      id: '123',
      email: req.body.email,
      name: req.body.name,
      created_at: new Date().toISOString()
    },
    access_token: 'fake-token',
    refresh_token: 'fake-refresh',
    expires_in: 3600
  });
});

app.listen(8000, () => {
  console.log('Test server running on port 8000 with CORS enabled');
});