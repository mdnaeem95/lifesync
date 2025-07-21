const express = require('express');
const { Pool } = require('pg');
const jwt = require('jsonwebtoken');

const app = express();
app.use(express.json());

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// JWT middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.sendStatus(401);
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) return res.sendStatus(403);
    req.user = user;
    next();
  });
};

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'flowtime' });
});

// Get user's tasks
app.get('/tasks', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM flowtime_tasks WHERE user_id = $1 ORDER BY scheduled_at',
      [req.user.user_id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching tasks:', error);
    res.status(500).json({ error: 'Failed to fetch tasks' });
  }
});

// Create task
app.post('/tasks', authenticateToken, async (req, res) => {
  const { title, description, scheduled_at, duration, task_type, energy_required, is_flexible } = req.body;
  
  try {
    const result = await pool.query(
      `INSERT INTO flowtime_tasks (user_id, title, description, scheduled_at, duration, task_type, energy_required, is_flexible)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [req.user.user_id, title, description, scheduled_at, duration, task_type, energy_required, is_flexible]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating task:', error);
    res.status(500).json({ error: 'Failed to create task' });
  }
});

// Get current energy level
app.get('/energy/current', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT * FROM flowtime_energy_levels 
       WHERE user_id = $1 
       ORDER BY recorded_at DESC 
       LIMIT 1`,
      [req.user.user_id]
    );
    
    if (result.rows.length === 0) {
      // Return default energy level
      res.json({ level: 70, recorded_at: new Date() });
    } else {
      res.json(result.rows[0]);
    }
  } catch (error) {
    console.error('Error fetching energy level:', error);
    res.status(500).json({ error: 'Failed to fetch energy level' });
  }
});

// Record energy level
app.post('/energy', authenticateToken, async (req, res) => {
  const { level, factors, source } = req.body;
  
  try {
    const result = await pool.query(
      `INSERT INTO flowtime_energy_levels (user_id, level, factors, source)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [req.user.user_id, level, factors || {}, source || 'manual']
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error recording energy level:', error);
    res.status(500).json({ error: 'Failed to record energy level' });
  }
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`FlowTime service listening on port ${PORT}`);
});