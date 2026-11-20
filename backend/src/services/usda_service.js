const axios = require('axios');
const { TtlCache } = require('../utils/ttl_cache');

const USDA_BASE_URL = 'https://api.nal.usda.gov/fdc/v1';

// USDA data changes rarely; caching avoids hitting the API rate limit.
const DAY_MS = 24 * 60 * 60 * 1000;
const searchCache = new TtlCache({ ttlMs: DAY_MS, maxEntries: 500 });
const detailsCache = new TtlCache({ ttlMs: DAY_MS, maxEntries: 300 });

async function fetchFoods(query) {
  const apiKey = process.env.USDA_API_KEY;

  if (!apiKey) {
    throw new Error('USDA_API_KEY is not configured');
  }

  const response = await axios.get(
    `${USDA_BASE_URL}/foods/search`,
    {
      params: {
        api_key: apiKey,
        query,
        dataType: 'Foundation, SR Legacy',
        pageSize: 10,
      },
      timeout: 15000,
    }
  );

  const foods = response.data.foods || [];

  return foods.map((food) => {
    const nutrients = food.foodNutrients || [];

    const getNutrient = (nutrientId) => {
      const nutrient = nutrients.find(
        (item) => item.nutrientId === nutrientId
      );

      return nutrient?.value ?? null;
    };

    return {
      fdcId: food.fdcId,
      description: food.description,
      dataType: food.dataType,
      nutrientsPer100g: {
        calories: getNutrient(1008),
        protein: getNutrient(1003),
        carbohydrates: getNutrient(1005),
        fat: getNutrient(1004),
        fiber: getNutrient(1079),
      },
    };
  });
}

  async function fetchFoodDetails(fdcId) {
  const apiKey = process.env.USDA_API_KEY;

  if (!apiKey) {
    throw new Error('USDA_API_KEY is not configured');
  }
      const requestUrl= `${USDA_BASE_URL}/food/${fdcId}`;
      console.log("usda url:", requestUrl);

  const response = await axios.get(
    `${USDA_BASE_URL}/food/${fdcId}`,
    {
      params: {
        api_key: apiKey,
      },
      timeout: 15000,
    }
  );
  return response.data;
}


function searchFoods(query) {
  const key = String(query).trim().toLowerCase();
  return searchCache.wrap(key, () => fetchFoods(query));
}

function getFoodDetails(fdcId) {
  return detailsCache.wrap(String(fdcId), () => fetchFoodDetails(fdcId));
}

module.exports = { searchFoods ,
  getFoodDetails
};