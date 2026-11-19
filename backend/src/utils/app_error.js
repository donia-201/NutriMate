/**
 * Error with an HTTP status code and a message that is safe to show
 * to the mobile app user. Anything that is NOT an AppError is treated
 * as an unexpected failure and answered with a generic message.
 */
class AppError extends Error {
  constructor(message, statusCode = 500, code = 'INTERNAL_ERROR') {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.code = code;
  }
}

module.exports = { AppError };
