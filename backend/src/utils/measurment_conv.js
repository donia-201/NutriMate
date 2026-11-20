 function normalize(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[.,]/g, ' ')
    .replace(/[()]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

// Supports: 2, 1.5, 1/2, 1 1/2
function parseQuantity(value) {
  const match = value.match(
    /^(\d+\s+\d+\s*\/\s*\d+|\d+\s*\/\s*\d+|\d+(?:\.\d+)?)/ 
  );

  if (!match) return null;

  const raw = match[1].trim();

  if (raw.includes(' ')) {
    const [whole, fraction] = raw.split(/\s+/);
    const [numerator, denominator] = fraction.split('/');

    if (Number(denominator) === 0) return null;

    return Number(whole) +
      Number(numerator) / Number(denominator);
  }

  if (raw.includes('/')) {
    const [numerator, denominator] = raw.split('/');

    if (Number(denominator) === 0) return null;

    return Number(numerator) / Number(denominator);
  }

  return Number(raw);
}

const UNIT_ALIASES = {
  eggs: 'egg',
  egg: 'egg',

  tablespoons: 'tablespoon',
  tablespoon: 'tablespoon',
  tbsp: 'tablespoon',
  tbs: 'tablespoon',

  teaspoons: 'teaspoon',
  teaspoon: 'teaspoon',
  tsp: 'teaspoon',

  cups: 'cup',
  cup: 'cup',

  slices: 'slice',
  slice: 'slice',

  cloves: 'clove',
  clove: 'clove',

  pieces: 'piece',
  piece: 'piece',
  pcs: 'piece',

  grams: 'gram',
  gram: 'gram',
  g: 'gram',

  kilograms: 'kilogram',
  kilogram: 'kilogram',
  kg: 'kilogram',

  milligrams: 'milligram',
  milligram: 'milligram',
  mg: 'milligram',

  ounces: 'ounce',
  ounce: 'ounce',
  oz: 'ounce',

  pounds: 'pound',
  pound: 'pound',
  lbs: 'pound',
  lb: 'pound',

  pints: 'pint',
  pint: 'pint',

  quarts: 'quart',
  quart: 'quart',

  gallons: 'gallon',
  gallon: 'gallon',

  cans: 'can',
  can: 'can',
  tins: 'can',
  tin: 'can',

  packages: 'package',
  package: 'package',
  packets: 'package',
  packet: 'package',

  bunches: 'bunch',
  bunch: 'bunch',

  pinches: 'pinch',
  pinch: 'pinch',

  dashes: 'dash',
  dash: 'dash',

  stalks: 'stalk',
  stalk: 'stalk',

  leaves: 'leaf',
  leaf: 'leaf',

  sprigs: 'sprig',
  sprig: 'sprig',

  sheets: 'sheet',
  sheet: 'sheet',

  cloves: 'clove',
  clove: 'clove',

  handfuls: 'handful',
  handful: 'handful',
};

const IGNORED_WORDS = new Set([
  'large',
  'medium',
  'small',
  'extra',
  'extra-large',
  'whole',
  'fresh',
  'raw',
  'chopped',
  'diced',
  'sliced',
  'minced',
  'crushed',
  'ground',
  'boneless',
  'skinless',
  'peeled',
  'seeded',
  'optional',
  'about',
  'approximately',
  'heaped',
  'level',
]);

function normalizeUnit(value) {
  const normalized = normalize(value);

  return UNIT_ALIASES[normalized] || normalized;
}

function getRequestedUnit(measure) {
  const normalized = normalize(measure);

  const unitText = normalized.replace(
    /^(\d+\s+\d+\s*\/\s*\d+|\d+\s*\/\s*\d+|\d+(?:\.\d+)?)\s*/,
    ''
  );

  const tokens = unitText
    .split(' ')
    .filter(Boolean)
    .filter((token) => !IGNORED_WORDS.has(token));

  return normalizeUnit(tokens.join(' '));
}

function findMatchingPortion(measure, portions = []) {
  const normalizedMeasure = normalize(measure);
  const quantity = parseQuantity(normalizedMeasure);

  if (
    quantity === null ||
    !Number.isFinite(quantity) ||
    quantity <= 0 ||
    !Array.isArray(portions)
  ) {
    return null;
  }

  const requestedUnit = getRequestedUnit(normalizedMeasure);

  if (!requestedUnit) return null;

  const candidates = portions
    .filter((portion) => {
      return (
        Number(portion.gramWeight) > 0 &&
        Number(portion.amount) > 0
      );
    })
    .map((portion) => {
      const unitName = normalizeUnit(
        portion.measureUnit?.name
      );

      const abbreviation = normalizeUnit(
        portion.measureUnit?.abbreviation
      );

      const modifier = normalize(portion.modifier);
      const description = normalize(
        portion.portionDescription
      );

      let score = 0;

      if (requestedUnit === unitName) score += 100;
      if (requestedUnit === abbreviation) score += 100;
 // Match known unit aliases and USDA descriptions.
      if (modifier === requestedUnit) score += 30;
      if (description === requestedUnit) score += 30;

      // Do not use generic reference portions as household units.
      if (
        unitName === 'racc' ||
        abbreviation === 'racc'
      ) {
        score = 0;
      }

      return { portion, score };
    })
    .filter((item) => item.score > 0)
    .sort((a, b) => b.score - a.score);

  const bestMatch = candidates[0];

  if (!bestMatch) return null;

  const portion = bestMatch.portion;

  const gramsPerUnit =
    Number(portion.gramWeight) / Number(portion.amount);

  const weightGrams = quantity * gramsPerUnit;

  if (!Number.isFinite(weightGrams) || weightGrams <= 0) {
    return null;
  }

  return {
    weightGrams: Number(weightGrams.toFixed(2)),
    weightSource: 'usda_portion',
    matchedPortion:
      portion.modifier ||
      portion.portionDescription ||
      portion.measureUnit?.name ||
      requestedUnit,
  };
}

module.exports = {
  normalize,
  parseQuantity,
  normalizeUnit,
  findMatchingPortion,
};