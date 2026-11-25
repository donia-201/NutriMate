const { GoogleGenAI } = require('@google/genai');
const { AppError } = require('../utils/app_error');
const { SYSTEM_INSTRUCTION } = require('../utils/ai_prompts');

const DEFAULT_MODEL = 'gemini-3.5-flash-lite';
// Used when GEMINI_FALLBACK_MODELS is not set, so a busy model never
// stops the feature on its own.
const DEFAULT_FALLBACK_MODELS = [
  'gemini-3.1-flash-lite',
  'gemini-3.6-flash',
  'gemini-3.8-flash',
];

// Time limits. The Flutter app waits 45 s and meal analysis makes two
// Gemini calls, so every call must finish (or fail) well before that.
const PER_ATTEMPT_TIMEOUT_MS = 9000;
const TOTAL_BUDGET_MS = 18000;
const MIN_ATTEMPT_MS = 1500;
const MAX_ROUNDS = 2;
const ROUND_PAUSE_MS = 700;

let client = null;

// Models that rejected the thinking setting; we stop sending it to them.
const thinkingRejected = new Set();

function getClient() {
  const apiKey = process.env.GEMINI_API_KEY;

  if (!apiKey) {
    throw new AppError(
      'The AI service is not configured yet.',
      503,
      'AI_NOT_CONFIGURED',
    );
  }

  if (!client) {
    client = new GoogleGenAI({ apiKey });
  }

  return client;
}

/**
 * Models to try in order: GEMINI_MODEL first, then the comma separated
 * GEMINI_FALLBACK_MODELS (or the built-in list when it is not set).
 */
function getModels() {
  const primary = process.env.GEMINI_MODEL || DEFAULT_MODEL;
  const configured = (process.env.GEMINI_FALLBACK_MODELS || '')
    .split(',')
    .map((name) => name.trim())
    .filter(Boolean);
  const fallbacks = configured.length > 0 ? configured : DEFAULT_FALLBACK_MODELS;

  return [...new Set([primary, ...fallbacks])];
}

function getStatus(error) {
  const status = Number(error?.status ?? error?.code);
  if (Number.isFinite(status)) return status;

  // The SDK sometimes only puts the API error JSON inside the message.
  const match = /"code"\s*:\s*(\d{3})/.exec(String(error?.message ?? ''));
  return match ? Number(match[1]) : NaN;
}

function isTimeout(error) {
  return (
    error?.name === 'AbortError' ||
    /timeout|timed out|aborted/i.test(String(error?.message ?? ''))
  );
}

// Worth moving on to the next model (or trying again shortly).
function isTemporary(error) {
  const status = getStatus(error);
  return (
    status === 429 ||
    status === 500 ||
    status === 503 ||
    status === 504 ||
    isTimeout(error)
  );
}

// This model cannot be used at all, so skip it for the rest of the request.
function isModelUnavailable(error) {
  return getStatus(error) === 404;
}

function toAppError(error) {
  const status = getStatus(error);

  if (status === 429) {
    return new AppError(
      'The AI service is busy. Please try again shortly.',
      429,
      'AI_RATE_LIMITED',
    );
  }

  if (status === 503 || status === 504 || isTimeout(error)) {
    return new AppError(
      'The AI service is temporarily unavailable. Please try again.',
      503,
      'AI_UNAVAILABLE',
    );
  }

  return new AppError(
    'The AI service could not complete your request.',
    502,
    'AI_REQUEST_FAILED',
  );
}

function buildConfig(model, responseSchema, temperature, timeoutMs) {
  const config = {
    systemInstruction: SYSTEM_INSTRUCTION,
    responseMimeType: 'application/json',
    responseSchema,
    httpOptions: { timeout: timeoutMs },
  };

  // Google recommends the default temperature for Gemini 3 models;
  // low values can make them slower or repeat themselves.
  if (!/^gemini-3/.test(model)) {
    config.temperature = temperature;
  }

  // Thinking makes answers much slower, and these tasks are simple.
  // GEMINI_THINKING_LEVEL can change it (minimal, low, medium, high),
  // or be set to "off" to send nothing.
  const level = (process.env.GEMINI_THINKING_LEVEL || 'low').toLowerCase();

  if (/^gemini-2\.5/.test(model)) {
    config.thinkingConfig = { thinkingBudget: 0 };
  } else if (level !== 'off' && !thinkingRejected.has(model)) {
    config.thinkingConfig = { thinkingLevel: level.toUpperCase() };
  }

  return config;
}

async function callModel(ai, model, { prompt, responseSchema, temperature }, timeoutMs) {
  const request = (config) =>
    ai.models.generateContent({ model, contents: prompt, config });

  const config = buildConfig(model, responseSchema, temperature, timeoutMs);

  try {
    return await request(config);
  } catch (error) {
    // Some models reject the thinking setting. Retry once without it.
    if (getStatus(error) === 400 && config.thinkingConfig) {
      console.error(`Gemini (${model}) rejected the thinking setting, retrying without it.`);
      thinkingRejected.add(model);
      delete config.thinkingConfig;
      return request(config);
    }

    throw error;
  }
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Sends one prompt to Gemini and returns the parsed JSON answer.
 * Moves quickly to the next model when one is busy, slow or unavailable,
 * and always finishes within TOTAL_BUDGET_MS.
 */
async function generateJson({ prompt, responseSchema, temperature = 0.3 }) {
  const ai = getClient();
  const models = getModels();
  const startedAt = Date.now();
  const remaining = () => TOTAL_BUDGET_MS - (Date.now() - startedAt);
  const unavailable = new Set();
  let lastError = null;
  let response = null;
  let usedModel = null;

  rounds: for (let round = 1; round <= MAX_ROUNDS; round += 1) {
    for (const model of models) {
      if (unavailable.has(model)) continue;
      if (remaining() < MIN_ATTEMPT_MS) break rounds;

      try {
        response = await callModel(
          ai,
          model,
          { prompt, responseSchema, temperature },
          Math.min(PER_ATTEMPT_TIMEOUT_MS, remaining()),
        );
        usedModel = model;
        break rounds;
      } catch (error) {
        lastError = error;
        console.error(
          `Gemini request failed (${model}, round ${round}):`,
          error?.message || error,
        );

        if (isModelUnavailable(error)) {
          unavailable.add(model);
          continue;
        }

        if (!isTemporary(error)) throw toAppError(error);
      }
    }

    if (unavailable.size === models.length) break;
    if (round < MAX_ROUNDS && remaining() > MIN_ATTEMPT_MS + ROUND_PAUSE_MS) {
      await sleep(ROUND_PAUSE_MS);
    }
  }

  if (!response) {
    throw lastError
      ? toAppError(lastError)
      : new AppError(
          'The AI service is temporarily unavailable. Please try again.',
          503,
          'AI_UNAVAILABLE',
        );
  }

  console.log(`Gemini ok (${usedModel}) in ${Date.now() - startedAt} ms`);

  const text = response?.text;

  if (!text) {
    throw new AppError(
      'The AI service returned an empty answer. Please try again.',
      502,
      'AI_EMPTY_RESPONSE',
    );
  }

  try {
    return JSON.parse(text);
  } catch (_) {
    console.error('Gemini returned invalid JSON:', text.slice(0, 200));
    throw new AppError(
      'The AI service returned an invalid answer. Please try again.',
      502,
      'AI_INVALID_RESPONSE',
    );
  }
}

module.exports = { generateJson };
