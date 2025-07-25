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
    const { date } = req.query;
    let query = 'SELECT * FROM flowtime_tasks WHERE user_id = $1';
    const params = [req.user.user_id];
    
    if (date) {
      query += ' AND DATE(scheduled_at) = DATE($2)';
      params.push(date);
    }
    
    query += ' ORDER BY scheduled_at';
    
    const result = await pool.query(query, params);
    
    // Convert snake_case to camelCase
    const tasks = result.rows.map(row => ({
      id: row.id,
      userId: row.user_id,
      title: row.title,
      description: row.description,
      scheduledAt: row.scheduled_at,
      duration: row.duration,
      taskType: row.task_type,
      priority: row.priority,
      energyRequired: row.energy_required,
      isCompleted: row.is_completed,
      isFlexible: row.is_flexible,
      completedAt: row.completed_at,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      metadata: row.metadata
    }));
    
    res.json(tasks);
  } catch (error) {
    console.error('Error fetching tasks:', error);
    res.status(500).json({ error: 'Failed to fetch tasks' });
  }
});

// Create task
app.post('/tasks', authenticateToken, async (req, res) => {
  const { 
    title, 
    description, 
    scheduledAt,  // Accept camelCase from Flutter
    duration, 
    taskType,     // Accept camelCase
    energyRequired, // Accept camelCase
    isFlexible    // Accept camelCase
  } = req.body;
  
  try {
    const result = await pool.query(
      `INSERT INTO flowtime_tasks 
       (user_id, title, description, scheduled_at, duration, task_type, 
        priority, energy_required, is_flexible)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [
        req.user.user_id, 
        title, 
        description, 
        scheduledAt,  // Use camelCase value
        duration, 
        taskType,     // Use camelCase value
        req.body.priority || 'medium',
        energyRequired, // Use camelCase value
        isFlexible !== undefined ? isFlexible : true
      ]
    );
    
    // Convert response to camelCase
    const task = result.rows[0];
    res.status(201).json({
      id: task.id,
      userId: task.user_id,
      title: task.title,
      description: task.description,
      scheduledAt: task.scheduled_at,
      duration: task.duration,
      taskType: task.task_type,
      priority: task.priority,
      energyRequired: task.energy_required,
      isCompleted: task.is_completed,
      isFlexible: task.is_flexible,
      completedAt: task.completed_at,
      createdAt: task.created_at,
      updatedAt: task.updated_at,
      metadata: task.metadata
    });
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