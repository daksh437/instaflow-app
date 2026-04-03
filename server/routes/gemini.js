const express = require('express');
const { generateCaptions, generateCalendar, generateStrategy, analyzeNiche } = require('../controllers/geminiController');

const router = express.Router();

router.post('/captions', generateCaptions);
router.post('/calendar', generateCalendar);
router.post('/strategy', generateStrategy);
router.post('/analyze', analyzeNiche);

module.exports = router;

