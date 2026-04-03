// Quick test to see if server can start
require('dotenv').config();
console.log('✅ dotenv loaded');
console.log('✅ GEMINI_API_KEY:', process.env.GEMINI_API_KEY ? 'Set' : 'Missing');
console.log('✅ PORT:', process.env.PORT || 8080);

const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

app.get('/health', (req, res) => {
  res.json({ success: true, message: 'OK' });
});

app.listen(port, () => {
  console.log(`🚀 Test server running on http://localhost:${port}`);
});

