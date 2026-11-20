const { searchFoods , getFoodDetails } = require('./usda_service');
const {
  calculateRecipeNutrition,
} = require('../utils/nutrition_calc');
const {
    findMatchingPortion,
    }= require('../utils/measurment_conv');

const NUTRIENT_KEYS = [
  'calories',
  'protein',
  'carbohydrates',
  'fat',
  'fiber',
];

function normalizeFoodName(value) {
  return (value || '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function selectBestFood(foods, ingredientName) {
  const query = normalizeFoodName(ingredientName);

  const rankedFoods = foods.map((food) => {
    const description = normalizeFoodName(food.description);
    let score = 0;

    if (description === query) {
      score += 100;
    }

    if (description.startsWith(query)) {
      score += 40;
    }

    const queryWords = query.split(' ');
    const descriptionWords = description.split(' ');

    for (const word of queryWords) {
      if (descriptionWords.includes(word)) {
        score += 10;
      }
    }

    // Penalize results that specify only a part of the food.
    if (description.includes('egg white') && !query.includes('egg white')) {
      score -= 60;
    }

    if (description.includes('yolk') && !query.includes('yolk')) {
      score -= 60;
    }

    return { food, score };
  });

  rankedFoods.sort((a, b) => b.score - a.score);

  return rankedFoods[0]?.food ?? null;
}

function parseWeightToGrams(measure) {
  if (!measure || typeof measure !== 'string') {
    return null;
  }

  const normalized = measure.trim().toLowerCase();

  const match = normalized.match(
    /^(\d+(?:\.\d+)?|\d+\s*\/\s*\d+)\s*(kg|g|gram|grams|mg|oz|ounce|ounces|lb|lbs|pound|pounds)\b/
  );

  if (!match) return null;

  let quantity;

  if (match[1].includes('/')) {
    const [numerator, denominator] = match[1]
      .split('/')
      .map(Number);

    if (!denominator) return null;

    quantity = numerator / denominator;
  } else {
    quantity = Number(match[1]);
  }

  const multipliers = {
    kg: 1000,
    g: 1,
    gram: 1,
    grams: 1,
    mg: 0.001,
    oz: 28.3495,
    ounce: 28.3495,
    ounces: 28.3495,
    lb: 453.592,
    lbs: 453.592,
    pound: 453.592,
    pounds: 453.592,
  };

  return quantity * multipliers[match[2]];
}

async function calculateMealNutrition(ingredients) {
  if (!Array.isArray(ingredients) || ingredients.length === 0) {
    throw new Error('Ingredients must be a non-empty array.');
  }

  const resolvedIngredients = await Promise.all(
    ingredients.map(async (ingredient) => {
      const name = ingredient.name?.trim();
      const measure = ingredient.measure?.trim() ?? '';

      if (!name) {
        throw new Error('Every ingredient must have a name.');
      }

      const foods = await searchFoods(name);

      if (!foods.length) {
        return {
          name,
          measure,
          unresolved: true,
          reason: 'No matching food was found in USDA.',
        };
      }

      const selectedFood = selectBestFood(foods, name);
    if (!selectedFood) {
      return {
      name,
    measure,
    unresolved: true,
    reason: 'No suitable USDA food match was found.',
  };
}

 let weightGrams = parseWeightToGrams(measure);
let weightSource = 'measured';
let matchedPortion = null;

if (!weightGrams) {
  const foodDetails = await getFoodDetails(selectedFood.fdcId);

  const conversion = findMatchingPortion(
    measure,
    foodDetails.foodPortions || []
  );

  if (conversion) {
    weightGrams = conversion.weightGrams;
    weightSource = conversion.weightSource;
    matchedPortion = conversion.matchedPortion;
  }
}

if (!weightGrams) {
  return {
    name,
    measure,
    unresolved: true,
    reason: 'No reliable quantity conversion was found.',
  };
}

      const nutrientsPer100g = selectedFood.nutrientsPer100g;

      const hasNutritionData = NUTRIENT_KEYS.some(
        (key) => nutrientsPer100g?.[key] !== null &&
          nutrientsPer100g?.[key] !== undefined
      );

      if (!hasNutritionData) {
        return {
          name,
          measure,
          unresolved: true,
          reason: 'USDA did not return usable nutrient data.',
        };
      }

      return {
        name,
        measure,
        weightGrams,
        weightSource ,
        matchedPortion,
        fdcId:selectedFood.fdcId,
        usdaFood: selectedFood.description,
        nutrientsPer100g,
      };
    })
  );

  const unresolvedIngredients = resolvedIngredients.filter(
    (item) => item.unresolved
  );

  const calculableIngredients = resolvedIngredients.filter(
    (item) => !item.unresolved
  );

  if (calculableIngredients.length === 0) {
    return {
      success: false,
      message: 'No ingredients could be calculated.',
      unresolvedIngredients,
    };
  }

  const result = calculateRecipeNutrition(calculableIngredients);

    return {
  success: true,
  ...result,
  isEstimated: result.isEstimated,
  isComplete:
    unresolvedIngredients.length === 0 &&
    result.missingNutrients.length === 0,
  hasUnresolvedIngredients: unresolvedIngredients.length > 0,
  unresolvedIngredients,
  disclaimer:
    'Nutrition values are estimates and depend on food matching and quantity accuracy.',
};
}

module.exports = {
  calculateMealNutrition,
  selectBestFood,
};