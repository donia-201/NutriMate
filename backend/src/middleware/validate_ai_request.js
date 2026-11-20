const { AppError } = require('../utils/app_error');

// Must match DietaryPreferencesWidget.preferences in the Flutter app.
const ALLOWED_PREFERENCES = [
  'Vegan',
  'Vegetarian',
  'Gluten-Free',
  'Low-Carb',
  'Diabetic-Friendly',
  'Dairy-Free',
  'Nut-Free',
];

const MAX_MEAL_LENGTH = 500;
const MAX_ADDITIONAL_LENGTH = 300;

function cleanText(value) {
  return String(value)
    .replace(/[\u0000-\u001F\u007F]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Validates the body sent by MealAnalysisRequest.toJson() and stores the
 * cleaned values on req.aiInput for the controller.
 */
function validateAiRequest(req, res, next) {
  const body = req.body ?? {};

  if (typeof body.mealDescription !== 'string') {
    throw new AppError('Please describe your meal first.', 400, 'INVALID_INPUT');
  }

  const mealDescription = cleanText(body.mealDescription);

  if (!mealDescription) {
    throw new AppError('Please describe your meal first.', 400, 'INVALID_INPUT');
  }

  if (mealDescription.length > MAX_MEAL_LENGTH) {
    throw new AppError(
      `Meal description must be at most ${MAX_MEAL_LENGTH} characters.`,
      400,
      'INVALID_INPUT',
    );
  }

  const rawPreferences = Array.isArray(body.dietaryPreferences)
    ? body.dietaryPreferences
    : [];

  const dietaryPreferences = [
    ...new Set(
      rawPreferences.filter((item) => ALLOWED_PREFERENCES.includes(item)),
    ),
  ];

  let additionalRequest = null;

  if (body.additionalRequest !== undefined && body.additionalRequest !== null) {
    if (typeof body.additionalRequest !== 'string') {
      throw new AppError('Invalid additional request.', 400, 'INVALID_INPUT');
    }

    additionalRequest = cleanText(body.additionalRequest) || null;

    if (additionalRequest && additionalRequest.length > MAX_ADDITIONAL_LENGTH) {
      throw new AppError(
        `Additional request must be at most ${MAX_ADDITIONAL_LENGTH} characters.`,
        400,
        'INVALID_INPUT',
      );
    }
  }

  req.aiInput = { mealDescription, dietaryPreferences, additionalRequest };
  next();
}

module.exports = { validateAiRequest, ALLOWED_PREFERENCES };
