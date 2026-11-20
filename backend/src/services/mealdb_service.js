const axios = require('axios');
const { AppError } = require('../utils/app_error');
const { TtlCache } = require('../utils/ttl_cache');

const MEALDB_BASE_URL = 'https://www.themealdb.com/api/json/v1/1';
const DAY_MS = 24 * 60 * 60 * 1000;

const http = axios.create({ baseURL: MEALDB_BASE_URL, timeout: 10000 });

const categoriesCache = new TtlCache({ ttlMs: DAY_MS, maxEntries: 1 });
const mealCache = new TtlCache({ ttlMs: DAY_MS, maxEntries: 500 });

function normalizeMeal(raw) {
  const ingredients = [];

  for (let i = 1; i <= 20; i += 1) {
    const name = String(raw[`strIngredient${i}`] ?? '').trim();
    if (name) ingredients.push(name);
  }

  return {
    id: String(raw.idMeal),
    name: raw.strMeal,
    category: raw.strCategory ?? null,
    area: raw.strArea ?? null,
    imageUrl: raw.strMealThumb ?? null,
    ingredients,
  };
}

async function fetchMeals(path, params) {
  const response = await http.get(path, { params });
  const meals = response.data?.meals;
  return Array.isArray(meals) ? meals : [];
}

function listCategories() {
  return categoriesCache.wrap('categories', async () => {
    const meals = await fetchMeals('/list.php', { c: 'list' });
    return meals.map((item) => item.strCategory).filter(Boolean);
  });
}

async function searchIdsByName(term) {
  const meals = (await fetchMeals('/search.php', { s: term })).map(normalizeMeal);

  // Full details are already here, so avoid a second lookup later.
  meals.forEach((meal) => mealCache.set(meal.id, meal));

  return meals.map((meal) => meal.id);
}

async function filterIdsByIngredient(term) {
  const ingredient = term.trim().toLowerCase().replace(/\s+/g, '_');
  const meals = await fetchMeals('/filter.php', { i: ingredient });
  return meals.map((item) => String(item.idMeal));
}

async function filterIdsByCategory(category) {
  const meals = await fetchMeals('/filter.php', { c: category });
  return meals.map((item) => String(item.idMeal));
}

function getMealDetails(id) {
  return mealCache.wrap(id, async () => {
    const meals = await fetchMeals('/lookup.php', { i: id });
    return meals[0] ? normalizeMeal(meals[0]) : null;
  });
}

/**
 * Finds real TheMealDB recipes related to the given search terms and
 * categories, and returns their details (including ingredient names).
 */
async function findCandidateMeals({
  terms,
  categories,
  perSource = 4,
  limit = 12,
}) {
  const tasks = [
    ...terms.flatMap((term) => [
      searchIdsByName(term),
      filterIdsByIngredient(term),
    ]),
    ...categories.map((category) => filterIdsByCategory(category)),
  ];

  if (tasks.length === 0) return [];

  const settled = await Promise.allSettled(tasks);
  const lists = settled
    .filter((item) => item.status === 'fulfilled')
    .map((item) => item.value);

  if (lists.length === 0) {
    console.error('TheMealDB search failed:', settled[0]?.reason?.message);
    throw new AppError(
      'Could not retrieve recipes right now. Please try again.',
      502,
      'MEALDB_FAILED',
    );
  }

  // Take results in turns from every source so one source cannot dominate.
  const ids = [];
  const seen = new Set();

  for (let i = 0; i < perSource; i += 1) {
    for (const list of lists) {
      const id = list[i];
      if (id && !seen.has(id)) {
        seen.add(id);
        ids.push(id);
      }
    }
  }

  const meals = await Promise.all(
    ids.slice(0, limit).map((id) => getMealDetails(id).catch(() => null)),
  );

  return meals.filter(Boolean);
}

module.exports = { listCategories, findCandidateMeals };
