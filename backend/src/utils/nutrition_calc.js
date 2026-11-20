const NUTRIENT_KEYS = [
  'calories',
  'protein',
  'carbohydrates',
  'fat',
  'fiber',
];

function round(value, decimals = 1) {
  if (value === null ||  value === undefined || !Number.isFinite(value)) {
    return null;
  }

  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}

/**
 * Calculates the nutrition of the entire recipe.
 *
 * Each ingredient must contain:
 * {
 *   name: string,
 *   weightGrams: number,
 *   nutrientsPer100g: {
 *     calories: number | null,
 *     protein: number | null,
 *     carbohydrates: number | null,
 *     fat: number | null,
 *     fiber: number | null
 *   },
 *   weightSource: 'measured' | 'estimated'
 * }
 */
function calculateRecipeNutrition(ingredients) {
  if (!Array.isArray(ingredients) || ingredients.length === 0) {
    throw new Error('At least one ingredient is required.');
  }

  const totals = Object.fromEntries(
    NUTRIENT_KEYS.map((key) => [key, 0]),
  );

  const missingNutrients = new Set();
  let hasEstimatedWeight = false;

  const ingredientResults = ingredients.map((ingredient) => {
    const weight = Number(ingredient.weightGrams);

    if (!Number.isFinite(weight) || weight <= 0) {
      throw new Error(
        `Invalid weight for ingredient: ${ingredient.name}`,
      );
    }

    if (ingredient.weightSource === 'estimated') {
      hasEstimatedWeight = true;
    }

    const contribution = {};

    for (const key of NUTRIENT_KEYS) {
      const value = ingredient.nutrientsPer100g?.[key];

      if (value === null || value === undefined || !Number.isFinite(Number(value))) {
        contribution[key] = null;
        missingNutrients.add(key);
        continue;
      }

      const amount = (Number(value) * weight) / 100;

      contribution[key] = round(amount);
      totals[key] += amount;
    }

    return {
      name: ingredient.name,
      measure: ingredient.measure ?? null,
      fdcId:ingredient.fdcId??null,
      weightGrams: weight,
      weightSource: ingredient.weightSource,
      usdaFood: ingredient.usdaFood ?? null,
      nutrition: contribution,
    };
  });

  // Do not present partial sums as complete totals.
  for (const key of NUTRIENT_KEYS) {
    if (missingNutrients.has(key)) {
      totals[key] = null;
    } else {
      totals[key] = round(totals[key]);
    }
  }

  return {
    scope: 'whole_recipe',
    nutrition: totals,
    isEstimated: hasEstimatedWeight,
    missingNutrients: [...missingNutrients],
    ingredients: ingredientResults,
  };
}

module.exports = {
  calculateRecipeNutrition,
};