const { GoogleGenAI } = require('@google/genai');
const { AppError } = require('../utils/app_error');
const { SYSTEM_INSTRUCTION } = require('../utils/ai_prompts');

const DEFAULT_MODEL = 'gemini-3.8-flash';
const REQUEST_TIMEOUT_MS = 20000;
const ATTEMPTS_PER_MODEL = 2;
const RETRY_DELAY_MS = 1000;
// Stop starting new attempts after this long, so the app gets an answer
// (or a clear error) before its own timeout.
const TOTAL_BUDGET_MS = 25000;

let client = null;

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
    client = new GoogleGenAI({
      apiKey,
      httpOptions: { timeout: REQUEST_TIMEOUT_MS },
    });
  }

  return client;
}

/**
 * Models to try in order: GEMINI_MODEL first, then the comma separated
 * GEMINI_FALLBACK_MODELS (used when the first one is busy or unavailable).
 */
function getModels() {
  const primary = process.env.GEMINI_MODEL || DEFAULT_MODEL;
  const fallbacks = (process.env.GEMINI_FALLBACK_MODELS || '')
    .split(',')
    .map((name) => name.trim())
    .filter(Boolean);

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
  return /timeout|timed out|aborted/i.test(String(error?.message ?? ''));
}

// Worth retrying or moving on to the next model.
function isTemporary(error) {
  const status = getStatus(error);
  return status === 429 || status === 500 || status === 503 ||
    status === 504 || isTimeout(error);
}

// This model cannot be used at all, so try the next one.
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

function buildConfig(model, responseSchema, temperature) {
  const config = {
    systemInstruction: SYSTEM_INSTRUCTION,
    temperature,
    responseMimeType: 'application/json',
    responseSchema,
  };

  // Gemini 2.5 models "think" by default, which adds seconds of latency.
  if (/^gemini-2\.5/.test(model)) {
    config.thinkingConfig = { thinkingBudget: 0 };
  }

  // Optional for newer models, for example GEMINI_THINKING_LEVEL=low.
  if (process.env.GEMINI_THINKING_LEVEL && !/^gemini-2\.5/.test(model)) {
    config.thinkingConfig = {
      thinkingLevel: process.env.GEMINI_THINKING_LEVEL.toUpperCase(),
    };
  }

  return config;
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Sends one prompt to Gemini and returns the parsed JSON answer.
 * Retries temporary failures and falls back to the next configured model.
 */
async function generateJson({ prompt, responseSchema, temperature = 0.3 }) {
  const ai = getClient();
  const startedAt = Date.now();
  let lastError = null;
  let response = null;

  outer: for (const model of getModels()) {
    for (let attempt = 1; attempt <= ATTEMPTS_PER_MODEL; attempt += 1) {
      if (Date.now() - startedAt > TOTAL_BUDGET_MS) break outer;

      try {
        response = await ai.models.generateContent({
          model,
          contents: prompt,
          config: buildConfig(model, responseSchema, temperature),
        });
        break outer;
      } catch (error) {
        lastError = error;
        console.error(
          `Gemini request failed (${model}, attempt ${attempt}):`,
          error?.message || error,
        );

        if (isModelUnavailable(error)) break; // next model
        if (!isTemporary(error)) throw toAppError(error);

        if (attempt < ATTEMPTS_PER_MODEL) await sleep(RETRY_DELAY_MS);
      }
    }
  }

  if (!response) throw toAppError(lastError);

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
