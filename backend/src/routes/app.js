const express = require('express');
const cors = require('cors');
const nutritionRoutes = require('../routes/nutrition_routes');

const app = express();

app.use(cors());
app.use(express.json());
app.use('/api/nutrition',nutritionRoutes);
// app.use('/test-portions/fdcId', );

app.get('/api/health',(req, res)=>{
    res.status(200).json({
        success: true,
        message:'NutriMate Api is running',
    });
});
  module.exports = app;