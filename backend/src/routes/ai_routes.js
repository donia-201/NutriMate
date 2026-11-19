const express = require('express');
const aiController = require('../controllers/ai_controller');
const { validateAiRequest } = require('../middleware/validate_ai_request');

const router = express.Router();

router.post('/meal-analysis', validateAiRequest, aiController.analyzeMeal);

router.post(
  '/healthy-alternatives',
  validateAiRequest,
  aiController.findHealthyAlternatives,
);

module.exports = router;
