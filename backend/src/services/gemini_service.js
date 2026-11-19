const { GoogleGenAI } = require('@google/genai');
const { AppError } = require('../utils/app_error');
const { SYSTEM_INSTRUCTION } = require('../utils/ai_prompts');

const DEFAULT_MODEL = 'gemini-2.5-flash';
const REQUEST_TIMEOUT_MS = 30000;

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

function mapGeminiError(error) {
  const status = Number(error?.status ?? error?.code);

  console.error('Gemini request failed:', error?.message || error);

  if (status === 429) {
    return new AppError(
      'The AI service is busy. Please try again shortly.',
      429,
      'AI_RATE_LIMITED',
    );
  }

  if (status === 503 || status === 504) {
    return new AppError(
      'The AI service is temporarily unavailable.',
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

/**
 * Sends one prompt to Gemini and returns the parsed JSON answer.
 * The response is constrained by `responseSchema`.
 */
async function generateJson({ prompt, responseSchema, temperature = 0.3 }) {
  const ai = getClient();
  const model = process.env.GEMINI_MODEL || DEFAULT_MODEL;

  const config = {
    systemInstruction: SYSTEM_INSTRUCTION,
    temperature,
    responseMimeType: 'application/json',
    responseSchema,
  };

  // Gemini 2.5 models "think" by default, which adds seconds of latency.
  // These tasks are simple, and the Flutter client times out after 15 s.
  if (/^gemini-2\.5/.test(model)) {
    config.thinkingConfig = { thinkingBudget: 0 };
  }

  let response;

  try {
    response = await ai.models.generateContent({
      model,
      contents: prompt,
      config,
    });
  } catch (error) {
    throw mapGeminiError(error);
  }

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
