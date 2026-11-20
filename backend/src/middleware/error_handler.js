const { AppError } = require('../utils/app_error');

function notFound(req, res) {
  res.status(404).json({
    success: false,
    message: 'Route not found.',
  });
}

// Express 5 forwards rejected promises from async handlers to this function.
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  if (res.headersSent) return next(err);

  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({
      success: false,
      message: 'Request body must be valid JSON.',
    });
  }

  if (err.type === 'entity.too.large') {
    return res.status(413).json({
      success: false,
      message: 'Request body is too large.',
    });
  }

  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      success: false,
      message: err.message,
      code: err.code,
    });
  }

  console.error('Unexpected error:', err);

  return res.status(500).json({
    success: false,
    message: 'Something went wrong. Please try again.',
  });
}

module.exports = { notFound, errorHandler };
