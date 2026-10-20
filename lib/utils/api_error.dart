import 'package:dio/dio.dart';

/// True when the request never reached the server. The app records straight
/// to the server with no local queue, so this is the one failure that
/// justifies blocking a screen rather than showing an inline message.
bool isConnectionFailure(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return true;
    case DioExceptionType.unknown:
      return e.response == null;
    default:
      return false;
  }
}

/// The server's own wording where there is some, because the API returns
/// genuinely useful messages — overlapping ranges, over-linking, a blocked
/// status change. Falls back to [fallback] rather than exposing a stack trace.
String readableDioError(DioException e, String fallback) {
  if (isConnectionFailure(e)) {
    return 'No connection to the server. Check the plant network and try '
        'again.';
  }

  final body = e.response?.data;
  if (body is Map) {
    final message = body['error'] ?? body['message'];
    if (message != null && message.toString().trim().isNotEmpty) {
      return message.toString();
    }
  }

  final status = e.response?.statusCode;
  if (status == 401 || status == 403) {
    return 'Your session has expired. Sign in again to continue.';
  }

  return fallback;
}

/// Pulls the message out of a non-exception error response, for the endpoints
/// called with `validateStatus` relaxed to accept 4xx.
String readableResponseError(Response<dynamic>? response, String fallback) {
  final body = response?.data;
  if (body is Map) {
    final message = body['error'] ?? body['message'];
    if (message != null && message.toString().trim().isNotEmpty) {
      return message.toString();
    }
  }
  return fallback;
}
