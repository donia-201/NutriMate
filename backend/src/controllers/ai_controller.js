const aiService = require('../services/ai_service');

async function analyzeMeal(req, res) {
  const data = await aiService.analyzeMeal(req.aiInput);
  res.status(200).json({ success: true, data });
}

async function findHealthyAlternatives(req, res) {
  const data = await aiService.findHealthyAlternatives(req.aiInput);
  res.status(200).json({ success: true, data });
}

module.exports = { analyzeMeal, findHealthyAlternatives };
