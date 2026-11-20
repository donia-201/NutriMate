const { generateJson } = require('./gemini_service');
const { calculateMealNutrition } = require('./nutrition_service');
const { listCategories, findCandidateMeals } = require('./mealdb_service');
const { AppError } = require('../utils/app_error');
const {
  mealParseSchema,
  mealInsightSchema,
  searchPlanSchema,
  rankingSchema,
} = require('../utils/ai_schemas');
const {
  buildMealParsePrompt,
  buildMealInsightPrompt,
  buildSearchPlanPrompt,
  buildRankingPrompt,
} = require('../utils/ai_prompts');

const MAX_INGREDIENTS = 15;
const MAX_GRAMS_PER_INGREDIENT = 3000;
const MAX_ALTERNATIVES = 5;

const DISCLAIMER =
  'Nutrition values are estimates and depend on food matching and quantity accuracy.';

function cleanIngredients(rawIngredients) {
  if (!Array.isArray(rawIngredients)) return [];

  return rawIngredients
    .map((item) => ({
      name: String(item?.name ?? '').trim(),
      grams: Number(item?.grams),
      quantityStated: item?.quantityStated === true,
    }))
    .filter(
      (item) =>
        item.name &&
        Number.isFinite(item.grams) &&
        item.grams > 0 &&
        item.grams <= MAX_GRAMS_PER_INGREDIENT,
    )
    .slice(0, MAX_INGREDIENTS);
}

function cleanStrings(values, max) {
  if (!Array.isArray(values)) return [];

  return [
    ...new Set(
      values
        .map((value) => String(value ?? '').trim())
        .filter(Boolean),
    ),
  ].slice(0, max);
}

function clampScore(value) {
  const score = Number(value);
  if (!Number.isFinite(score)) return null;
  return Math.round(Math.min(10, Math.max(0, score)) * 10) / 10;
}

async function computeNutrition(ingredients) {
  try {
    // "150 g" is understood by the existing nutrition pipeline.
    return await calculateMealNutrition(
      ingredients.map((item) => ({
        name: item.name,
        measure: `${Math.round(item.grams * 10) / 10} g`,
      })),
    );
  } catch (error) {
    console.error('Nutrition calculation failed:', error.message);
    throw new AppError(
      'Could not retrieve nutrition data. Please try again.',
      502,
      'NUTRITION_FAILED',
    );
  }
}

/**
 * Meal analysis:
 *  1. Gemini turns the free text into ingredients with grams.
 *  2. The existing USDA pipeline calculates the real numbers.
 *  3. Gemini writes the score, assessment and tips from those numbers.
 */
async function analyzeMeal({ mealDescription, dietaryPreferences }) {
  const parsed = await generateJson({
    prompt: buildMealParsePrompt({ mealDescription }),
    responseSchema: mealParseSchema,
    temperature: 0.1,
  });

  const ingredients = parsed.isFood ? cleanIngredients(parsed.ingredients) : [];

  if (ingredients.length === 0) {
    throw new AppError(
      'I could not find any food in that description. Try something like "2 eggs and a slice of toast".',
      422,
      'NO_FOOD_FOUND',
    );
  }

  const calculation = await computeNutrition(ingredients);

  if (!calculation.success) {
    throw new AppError(
      'I could not find nutrition data for these foods. Try describing them more simply.',
      422,
      'NO_NUTRITION_DATA',
    );
  }

  const unresolvedNames = (calculation.unresolvedIngredients ?? []).map(
    (item) => item.name,
  );

  const isComplete = calculation.isComplete === true;
  const isEstimated =
    calculation.isEstimated === true ||
    ingredients.some((item) => !item.quantityStated);

  const nutrition = {
    ...calculation.nutrition,
    isComplete,
    isEstimated,
    scope: 'whole_meal',
    missingNutrients: calculation.missingNutrients ?? [],
    unresolvedIngredients: unresolvedNames,
    disclaimer: DISCLAIMER,
  };

  const insight = await generateJson({
    prompt: buildMealInsightPrompt({
      mealDescription,
      dietaryPreferences,
      ingredients,
      nutrition: calculation.nutrition,
      isComplete,
    }),
    responseSchema: mealInsightSchema,
    temperature: 0.4,
  });

  return {
    nutrition,
    balanceScore: clampScore(insight.balanceScore),
    assessment: String(insight.assessment ?? '').trim(),
    tips: cleanStrings(insight.tips, 4),
  };
}

/**
 * Healthy alternatives:
 *  1. Gemini decides what to search for in TheMealDB.
 *  2. We fetch real recipes from TheMealDB.
 *  3. Gemini picks and explains the best ones. Only real ids are returned.
 */
async function findHealthyAlternatives({
  mealDescription,
  dietaryPreferences,
  additionalRequest,
}) {
  const allCategories = await listCategories();

  const plan = await generateJson({
    prompt: buildSearchPlanPrompt({
      mealDescription,
      dietaryPreferences,
      additionalRequest,
      categories: allCategories,
    }),
    responseSchema: searchPlanSchema,
    temperature: 0.2,
  });

  const terms = cleanStrings(plan.searchTerms, 3);
  const categories = cleanStrings(plan.categories, 3).filter((name) =>
    allCategories.includes(name),
  );

  // Dedicated TheMealDB categories exist for these two preferences.
  for (const preference of ['Vegan', 'Vegetarian']) {
    if (
      dietaryPreferences.includes(preference) &&
      allCategories.includes(preference) &&
      !categories.includes(preference)
    ) {
      categories.push(preference);
    }
  }

  const candidates = await findCandidateMeals({ terms, categories });

  if (candidates.length === 0) {
    return { alternatives: [] };
  }

  const ranking = await generateJson({
    prompt: buildRankingPrompt({
      mealDescription,
      dietaryPreferences,
      additionalRequest,
      candidates,
    }),
    responseSchema: rankingSchema,
    temperature: 0.3,
  });

  const candidatesById = new Map(candidates.map((item) => [item.id, item]));
  const usedIds = new Set();
  const alternatives = [];

  for (const choice of ranking.alternatives ?? []) {
    const id = String(choice?.id ?? '').trim();
    const meal = candidatesById.get(id);

    // Never return an id that did not come from TheMealDB.
    if (!meal || usedIds.has(id)) continue;
    usedIds.add(id);

    alternatives.push({
      recipe: {
        id: meal.id,
        name: meal.name,
        imageUrl: meal.imageUrl,
        category: meal.category,
        area: meal.area,
      },
      reason: String(choice.reason ?? '').trim(),
      improvementSummary:
        String(choice.improvementSummary ?? '').trim() || null,
    });

    if (alternatives.length >= MAX_ALTERNATIVES) break;
  }

  return { alternatives };
}

module.exports = { analyzeMeal, findHealthyAlternatives };
