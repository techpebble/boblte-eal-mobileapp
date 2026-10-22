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

  final status = e.response?.statusCode;

  // 503 is the server saying it cannot reach its records. It writes that
  // sentence for the operator, and the important half of it is that they
  // have not been signed out: a database that will not answer used to come
  // back as a failed token and empty the session.
  if (status == 503) {
    final body = e.response?.data;
    final message = body is Map ? body['message'] : null;
    if (message != null && message.toString().trim().isNotEmpty) {
      return message.toString();
    }
    return 'The server cannot reach its records at the moment. You are '
        'still signed in; try again shortly.';
  }

  // Any other 5xx body is whatever the server threw, written for whoever
  // reads the logs: "bad auth : authentication failed" tells an operator
  // nothing, and names the plumbing besides. The 4xx ones are written for
  // them — an overlapping range, a refusal, a note that is still a draft.
  if (status != null && status >= 500) {
    return 'The server had a problem with that. Try again, and tell a '
        'supervisor if it keeps happening.';
  }

  final body = e.response?.data;
  if (body is Map) {
    final message = body['error'] ?? body['message'];
    if (message != null && message.toString().trim().isNotEmpty) {
      return message.toString();
    }
  }

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

/// The same, for a `catch (e)` that has not narrowed the type. Anything
/// that is not a Dio failure gets [fallback] rather than its toString, which
/// on a DioException runs to the request options and a stack trace.
String readableError(Object error, String fallback) {
  if (error is DioException) return readableDioError(error, fallback);
  return fallback;
}

/// Whether a failure means the session itself is finished, rather than this
/// one action being refused.
///
/// A 401 is a token the server will not take — expired, malformed, or
/// belonging to a user that no longer exists. A 403 from the sign-in guard
/// means the account has been switched off. Neither can be recovered from
/// inside the app, so both end the session.
///
/// A 403 from the permission guard is a different thing: the role is fine,
/// this one action is not allowed, and the screen says so itself. The server
/// marks those by naming the permission it wanted, which is how the two are
/// told apart.
bool endsTheSession(DioException error) {
  final status = error.response?.statusCode;
  if (status == 401) return true;
  if (status != 403) return false;

  final body = error.response?.data;
  final refusedOneAction = body is Map && body['required'] != null;
  return !refusedOneAction;
}
