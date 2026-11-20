const { Type } = require('@google/genai');

// Step 1 of meal analysis: free text -> structured ingredients.
const mealParseSchema = {
  type: Type.OBJECT,
  properties: {
    isFood: { type: Type.BOOLEAN },
    ingredients: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          name: { type: Type.STRING },
          grams: { type: Type.NUMBER },
          quantityStated: { type: Type.BOOLEAN },
        },
        required: ['name', 'grams', 'quantityStated'],
      },
    },
  },
  required: ['isFood', 'ingredients'],
};

// Step 2 of meal analysis: written feedback on computed numbers.
const mealInsightSchema = {
  type: Type.OBJECT,
  properties: {
    balanceScore: { type: Type.NUMBER },
    assessment: { type: Type.STRING },
    tips: { type: Type.ARRAY, items: { type: Type.STRING } },
  },
  required: ['balanceScore', 'assessment', 'tips'],
};

// Healthy alternatives, step 1: what to look for in TheMealDB.
const searchPlanSchema = {
  type: Type.OBJECT,
  properties: {
    searchTerms: { type: Type.ARRAY, items: { type: Type.STRING } },
    categories: { type: Type.ARRAY, items: { type: Type.STRING } },
  },
  required: ['searchTerms', 'categories'],
};

// Healthy alternatives, step 2: pick and explain from real candidates.
const rankingSchema = {
  type: Type.OBJECT,
  properties: {
    alternatives: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          id: { type: Type.STRING },
          reason: { type: Type.STRING },
          improvementSummary: { type: Type.STRING },
        },
        required: ['id', 'reason', 'improvementSummary'],
      },
    },
  },
  required: ['alternatives'],
};

module.exports = {
  mealParseSchema,
  mealInsightSchema,
  searchPlanSchema,
  rankingSchema,
};
