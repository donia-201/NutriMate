const axios = require('axios');

const USDA_BASE_URL = 'https://api.nal.usda.gov/fdc/v1';

async function searchFoods(query) {
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

  async function getFoodDetails(fdcId) {
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


module.exports = { searchFoods ,
  getFoodDetails
};