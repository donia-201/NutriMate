const express = require('express');
const cors = require('cors');
const nutritionRoutes = require('../routes/nutrition_routes');
const aiRoutes = require('../routes/ai_routes');
const { createRateLimiter } = require('../middleware/rate_limiter');
const { notFound, errorHandler } = require('../middleware/error_handler');

const app = express();

// Needed on hosting platforms so req.ip is the real client address.
app.set('trust proxy', 1);

app.use(cors());
app.use(express.json({ limit: '10kb' }));

app.use('/api/nutrition', nutritionRoutes);

app.use(
  '/api/ai',
  createRateLimiter({
    windowMs: 10 * 60 * 1000,
    max: Number(process.env.AI_RATE_LIMIT_MAX) || 30,
  }),
  aiRoutes,
);

app.get('/api/health',(req, res)=>{
    res.status(200).json({
        success: true,
        message:'NutriMate Api is running',
    });
});

app.use(notFound);
app.use(errorHandler);

module.exports = app;
