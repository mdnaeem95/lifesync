// backend/quick-test-flowtime.js
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const app = express();

app.use(cors());
app.use(express.json());

// Use a test JWT secret
const JWT_SECRET = 'test-secret-key';

// Store for our fake users and tasks (in production, this would be a database)
const users = {};
const tasks = {}; // Store tasks by user_id

// Simple JWT verification middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  console.log('Auth header:', authHeader);
  console.log('Token:', token);

  if (!token) {
    console.log('No token provided');
    return res.sendStatus(401);
  }

  // For testing, let's decode without verification first
  try {
    const decoded = jwt.decode(token);
    console.log('Decoded token:', decoded);
    
    // Now try to verify
    jwt.verify(token, JWT_SECRET, (err, user) => {
      if (err) {
        console.log('JWT verification error:', err.message);
        // For development, let's be more lenient
        if (decoded && decoded.user_id) {
          console.log('Using decoded user_id despite verification failure');
          req.user = decoded;
          next();
        } else {
          return res.sendStatus(403);
        }
      } else {
        req.user = user;
        next();
      }
    });
  } catch (error) {
    console.log('Token decode error:', error);
    res.sendStatus(403);
  }
};

// Mock the auth endpoints
app.post('/auth/signin', (req, res) => {
  console.log('Sign in request:', req.body);
  
  const user = {
    id: '123e4567-e89b-12d3-a456-426614174000',
    email: req.body.email,
    name: req.body.email.split('@')[0],
    photoUrl: null,  // Optional field
    createdAt: new Date().toISOString()  // Changed from created_at to createdAt
  };
  
  // Store user for later
  users[user.id] = user;
  
  // Create tokens with matching structure
  const accessToken = jwt.sign(
    { 
      user_id: user.id,
      email: user.email,
      type: 'access'
    },
    JWT_SECRET,
    { expiresIn: '1h' }
  );
  
  const refreshToken = jwt.sign(
    { 
      user_id: user.id,
      type: 'refresh'
    },
    JWT_SECRET,
    { expiresIn: '30d' }
  );
  
  console.log('Generated access token:', accessToken);
  
  res.json({
    access_token: accessToken,
    refresh_token: refreshToken,
    expires_in: 3600,
    user: user
  });
});

app.post('/auth/signup', (req, res) => {
  console.log('Sign up request:', req.body);
  
  const user = {
    id: '123e4567-e89b-12d3-a456-426614174000',
    email: req.body.email,
    name: req.body.name || req.body.email.split('@')[0],
    photoUrl: null,  // Optional field
    createdAt: new Date().toISOString()  // Changed from created_at to createdAt
  };
  
  // Store user
  users[user.id] = user;
  
  // Create tokens
  const accessToken = jwt.sign(
    { 
      user_id: user.id,
      email: user.email,
      type: 'access'
    },
    JWT_SECRET,
    { expiresIn: '1h' }
  );
  
  const refreshToken = jwt.sign(
    { 
      user_id: user.id,
      type: 'refresh'
    },
    JWT_SECRET,
    { expiresIn: '30d' }
  );
  
  res.json({
    access_token: accessToken,
    refresh_token: refreshToken,
    expires_in: 3600,
    user: user
  });
});

app.post('/auth/refresh', (req, res) => {
  console.log('Refresh token request');
  const { refresh_token } = req.body;
  
  if (!refresh_token) {
    return res.status(401).json({ error: 'No refresh token provided' });
  }
  
  try {
    const decoded = jwt.verify(refresh_token, JWT_SECRET);
    
    // Generate new access token
    const accessToken = jwt.sign(
      { 
        user_id: decoded.user_id,
        type: 'access'
      },
      JWT_SECRET,
      { expiresIn: '1h' }
    );
    
    res.json({
      access_token: accessToken,
      refresh_token: refresh_token, // Return same refresh token
      expires_in: 3600
    });
  } catch (err) {
    console.log('Refresh token error:', err);
    res.status(403).json({ error: 'Invalid refresh token' });
  }
});

app.post('/auth/signout', (req, res) => {
  console.log('Sign out request');
  res.status(200).json({ message: 'Signed out successfully' });
});

// Mock FlowTime endpoints
app.get('/api/flowtime/tasks', authenticateToken, (req, res) => {
  console.log('Tasks request for user:', req.user);
  
  const userId = req.user.user_id;
  const userTasks = tasks[userId] || [];
  
  // Filter tasks by date if provided
  const dateParam = req.query.date;
  if (dateParam) {
    const requestedDate = new Date(dateParam);
    const filteredTasks = userTasks.filter(task => {
      const taskDate = new Date(task.scheduledAt);
      return taskDate.toDateString() === requestedDate.toDateString();
    });
    console.log(`Returning ${filteredTasks.length} tasks for date ${dateParam}`);
    res.json(filteredTasks);
  } else {
    console.log(`Returning all ${userTasks.length} tasks`);
    res.json(userTasks);
  }
});

app.post('/api/flowtime/tasks', authenticateToken, (req, res) => {
  console.log('Create task request:', req.body);
  console.log('User:', req.user);
  
  const userId = req.user.user_id;
  
  // Map the fields correctly to match Flutter's expectations
  const task = {
    id: Date.now().toString(),
    user_id: userId,
    title: req.body.title,
    description: req.body.description,
    scheduledAt: req.body.scheduledAt,  // camelCase
    duration: req.body.duration,
    taskType: req.body.taskType,  // camelCase
    priority: req.body.priority || 'medium',
    energyRequired: req.body.energyRequired,  // camelCase
    isCompleted: false,  // camelCase
    isFlexible: req.body.isFlexible !== undefined ? req.body.isFlexible : true,  // camelCase
    completedAt: null,  // camelCase
    createdAt: new Date().toISOString(),  // camelCase
    updatedAt: new Date().toISOString()   // camelCase
  };
  
  // Store the task
  if (!tasks[userId]) {
    tasks[userId] = [];
  }
  tasks[userId].push(task);
  
  console.log('Created task:', task);
  console.log(`Total tasks for user: ${tasks[userId].length}`);
  
  res.status(201).json(task);
});

app.get('/api/flowtime/energy/current', authenticateToken, (req, res) => {
  res.json({ level: 75 });
});

app.get('/api/flowtime/energy/predictions', authenticateToken, (req, res) => {
  // Generate 24 hour predictions
  const predictions = [];
  for (let i = 0; i < 24; i++) {
    predictions.push(Math.floor(50 + Math.sin(i / 4) * 30));
  }
  res.json({ predictions });
});

app.post('/api/flowtime/tasks/suggest-slots', authenticateToken, (req, res) => {
  console.log('Suggest slots request:', req.body);
  const now = new Date();
  res.json({
    time_slots: [
      new Date(now.getTime() + 2 * 60 * 60 * 1000).toISOString(),
      new Date(now.getTime() + 4 * 60 * 60 * 1000).toISOString(),
      new Date(now.getTime() + 6 * 60 * 60 * 1000).toISOString(),
    ]
  });
});

// Task update endpoints
app.patch('/api/flowtime/tasks/:taskId/toggle-complete', authenticateToken, (req, res) => {
  const { taskId } = req.params;
  const userId = req.user.user_id;
  
  if (tasks[userId]) {
    const task = tasks[userId].find(t => t.id === taskId);
    if (task) {
      task.isCompleted = !task.isCompleted;
      task.completedAt = task.isCompleted ? new Date().toISOString() : null;
      task.updatedAt = new Date().toISOString();
      console.log(`Toggled task ${taskId} completion to ${task.isCompleted}`);
    }
  }
  
  res.status(200).json({ success: true });
});

app.delete('/api/flowtime/tasks/:taskId', authenticateToken, (req, res) => {
  const { taskId } = req.params;
  const userId = req.user.user_id;
  
  if (tasks[userId]) {
    tasks[userId] = tasks[userId].filter(t => t.id !== taskId);
    console.log(`Deleted task ${taskId}`);
  }
  
  res.status(204).send();
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'test-flowtime-combined' });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ error: err.message });
});

const PORT = 8000;
app.listen(PORT, () => {
  console.log(`Test server running on http://localhost:${PORT}`);
  console.log('This combines auth and flowtime services for testing');
  console.log('JWT Secret:', JWT_SECRET);
  console.log('');
  console.log('To test:');
  console.log('1. Clear browser cache/storage');
  console.log('2. Sign in with any email/password');
  console.log('3. The timeline should load');
  console.log('4. You should be able to add tasks');
});