const express = require('express');
const { searchFoods } = require('../services/usda_service');

const router = express.Router();

router.get('/search', async (req, res) => {
  const query = req.query.query?.trim();

  if (!query) {
    return res.status(400).json({
      success: false,
      message: 'Please provide a food query.',
    });
  }

  try {
    const foods = await searchFoods(query);

    return res.status(200).json({
      success: true,
      count: foods.length,
      foods,
    });
  } catch (error) {
    const status = error.response?.status;

    console.error(
      'USDA search failed:',
      error.response?.data || error.message
    );

    return res.status(502).json({
      success: false,
      message: 'Could not retrieve nutrition data.',
    });
  }
});

const {
  calculateMealNutrition,
} = require('../services/nutrition_service');

router.post('/recipe', async (req, res) => {
  try {
    const { ingredients } = req.body;

    if (!Array.isArray(ingredients) || ingredients.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Please provide at least one ingredient.',
      });
    }

    const result = await calculateMealNutrition(ingredients);

    return res.status(200).json(result);
  } catch (error) {
    console.error('Recipe nutrition error:', error.message);

    return res.status(500).json({
      success: false,
      message: 'Failed to calculate recipe nutrition.',
    });
  }
});

router.get('/test-portions/:fdcId', async (req, res) => {
  try {
    const { getFoodDetails } = require('../services/usda_service');
    console.log("usda food id: ", req.params.fdcId);
    const food = await getFoodDetails(req.params.fdcId);

    res.json({
      description: food.description,
      foodPortions: food.foodPortions,
    });
  } catch (error) {
    res.status(500).json({
      message: error.message,
    });
  }
});


module.exports = router;