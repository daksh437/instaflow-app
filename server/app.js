// Legacy server copy — production WhatsApp webhook lives in ../backend/app.js only.
console.log('⚠️ server/app.js — use backend/ for Render (Root Directory: backend)');
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/auth');
const geminiRoutes = require('./routes/gemini');
const calendarRoutes = require('./routes/calendar');

const app = express();
const PORT = process.env.PORT || 10000;

// CORS for Flutter/web
const corsOrigins = (process.env.CORS_ORIGINS || '').split(',').filter(Boolean);
app.use(
  cors({
    origin: corsOrigins.length ? corsOrigins : '*',
    credentials: true,
  })
);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ROOT (before mounted routers)
app.get('/', (req, res) => {
  res.json({ success: true, message: 'InstaFlow Backend API' });
});

// Routes
app.use('/auth', authRoutes);
app.use('/ai', geminiRoutes);
app.use('/calendar', calendarRoutes);

// Request logging middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

app.get('/health', (_req, res) => {
  res.json({ success: true, message: 'OK' });
});

// Error handler
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('Unhandled error', err);
  res.status(500).json({ success: false, error: 'Internal Server Error' });
});

// Listen on all network interfaces (0.0.0.0) for cloud (Render) and local
app.listen(PORT, '0.0.0.0', () => {
  console.log('🚀 Server running on port', PORT);
  console.log(`🚀 InstaFlow backend running on http://localhost:${PORT}`);
  console.log(`✅ Server ready for requests!`);
});

