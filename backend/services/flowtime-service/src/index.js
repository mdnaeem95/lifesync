const express = require('express');
const { Pool } = require('pg');
const amqp = require('amqplib');
const jwt = require('jsonwebtoken');

const app = express();
app.use(express.json());

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// Message queue connection
let channel;
async function connectRabbitMQ() {
  const connection = await amqp.connect(process.env.RABBITMQ_URL);
  channel = await connection.createChannel();
  
  // Listen for user events
  await channel.assertQueue('user.created');
  channel.consume('user.created', async (msg) => {
    const user = JSON.parse(msg.content.toString());
    await initializeUserFlowTimeData(user);
    channel.ack(msg);
  });
}

// Middleware for auth
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

// Task endpoints
app.post('/tasks', authenticateToken, async (req, res) => {
  const { title, description, scheduledAt, duration, taskType, priority, energyRequired } = req.body;
  
  try {
    const result = await pool.query(`
      INSERT INTO flowtime_tasks 
      (user_id, title, description, scheduled_at, duration, task_type, priority, energy_required)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *
    `, [req.user.user_id, title, description, scheduledAt, duration, taskType, priority, energyRequired]);
    
    const task = result.rows[0];
    
    // Publish task created event
    await channel.sendToQueue('flowtime.task.created', Buffer.from(JSON.stringify(task)));
    
    res.json(task);
  } catch (error) {
    console.error('Error creating task:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/tasks', authenticateToken, async (req, res) => {
  const { date } = req.query;
  
  try {
    const result = await pool.query(`
      SELECT * FROM flowtime_tasks 
      WHERE user_id = $1 
      AND DATE(scheduled_at) = DATE($2)
      ORDER BY scheduled_at
    `, [req.user.user_id, date]);
    
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching tasks:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Energy level endpoints
app.post('/energy-levels', authenticateToken, async (req, res) => {
  const { level, factors } = req.body;
  
  try {
    const result = await pool.query(`
      INSERT INTO flowtime_energy_levels (user_id, level, factors)
      VALUES ($1, $2, $3)
      RETURNING *
    `, [req.user.user_id, level, factors]);
    
    const energyLevel = result.rows[0];
    
    // Send to ML service for processing
    await channel.sendToQueue('energy.recorded', Buffer.from(JSON.stringify(energyLevel)));
    
    res.json(energyLevel);
  } catch (error) {
    console.error('Error recording energy level:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, async () => {
  await connectRabbitMQ();
  console.log(`FlowTime service listening on port ${PORT}`);
});