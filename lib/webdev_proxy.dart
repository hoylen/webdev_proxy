/// Support for debugging client-side Dart scripts with Dart HTTP servers.
///
/// To debug client-side Dart scripts, _webdev serve_ is usually used to support
/// debugging with the Dart Development Compiler (DDC). When those client-side
/// scripts are loaded from HTML pages from a HTTP server, the browser expects
/// to retrieve those scripts from that same HTTP server. Therefore, when using
/// _webdev serve_ with HTML from a HTTP server, that HTTP server must also
/// handle requests that need to be handled by the _webdev serve_ process.
///
/// This package provides functions that can be used when the HTTP server is
/// implemented as a server-side Dart program. When the HTTP server is running
/// in debug mode, requests can be proxied through to _webdev serve_ using the
/// [respondFromServe] function. When running in produciton mode, the compiled
/// client-side scripts can be served using the [respondFromBuild] function.
///
/// The HTTP server should handle all HTTP requests normally, with any HTTP GET
/// requests that it can't handle passed to one of those functions to handle.
/// Which function to use depends on if debugging with "webdev server" is
/// desired or not.

library webdev_proxy;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

//================================================================
// Globals

/// Logger for this package

final Logger _log = Logger('webdev_proxy');

/// Table to translate filename extensions into MIME types.
///
/// This is used by [respondFromBuild] to set the MIME type of the HTTP response
/// based on the filename.

Map<String, ContentType> _defaultMimeTypes = {
  'txt': ContentType.text,
  'html': ContentType.html,
  'htm': ContentType.html,
  'json': ContentType.json,
  'css': ContentType('text', 'css'),
  'png': ContentType('image', 'png'),
  'jpg': ContentType('image', 'jpeg'),
  'jpeg': ContentType('image', 'jpeg'),
  'gif': ContentType('image', 'gif'),
  'ico': ContentType('image', 'vnd.microsoft.icon'),
  'xml': ContentType('application', 'xml'),
  'js': ContentType('application', 'javascript'),
  'dart': ContentType('application', 'dart'),
};

/// HTTP headers that are not passed back.
///
/// When [respondFromServe] copies the headers from the headers from the
/// "webdev serve" response, all headers are copied except for these.
///
/// Always use lowercase values (since these will be compared to the actual
/// header name converted into lowercase).

List<String> _defaultResponseHeadersDiscarded = [
  // 'x-frame-options',
  'x-xss-protection',
];
// List<String> _discardedResponseHeaders = [];

//================================================================
// Exceptions

//----------------------------------------------------------------
/// Abstract base class for all exceptions from this package.

abstract class WebdevProxyException implements Exception {
  /// Constructor
  WebdevProxyException(this.request, this.message);

  /// HTTP request that was being processed
  final HttpRequest request;

  /// Short message describing the cause
  final String message;

  @override
  String toString() => '${request.uri}: $message';
}

//----------------------------------------------------------------
/// Exception thrown when the request cannot be processed.

class BadRequest extends WebdevProxyException {
  /// Constructor
  BadRequest(HttpRequest req, String msg) : super(req, msg);
}

//----------------------------------------------------------------
/// Exception thrown when a requested file is not found.

class FileNotFound extends WebdevProxyException {
  /// Constructor
  FileNotFound(HttpRequest req, this.file)
      : super(req, 'file not found: ${file.path}');

  /// The file that was not found
  final File file;
}

//----------------------------------------------------------------
/// Exception thrown when the "webdev sever" proxy cannot be contacted.

class ServerUnavailable extends WebdevProxyException {
  /// Constructor
  ServerUnavailable(HttpRequest req, String msg) : super(req, msg);
}

//================================================================
// Functions for responding to HttpRequests from the file system.

//----------------------------------------------------------------
/// Handle HTTP GET requests using the compiled file assets.
///
/// Matches the HTTP request [req] to a file under the [buildDir] directory
/// and produce a HTTP response from it.
///
/// Throws [FileNotFound] if a file matching the path in the [req] cannot be
/// found.
///
/// Throws [BadRequest] if the path in the [req] is potentially malicious.
/// That is, if it contains ".." components, which are usually a sign of the
/// client trying to access files they shouldn't.

Future<void> respondFromBuild(HttpRequest req, String? buildDir) async {
  if (buildDir == null) {
    throw ArgumentError.notNull('buildDir');
  }
  if (!buildDir.startsWith(Platform.pathSeparator)) {
    throw ArgumentError.value(buildDir, 'buildDir', 'not absolute path');
  }
  if (req.method != 'GET') {
    throw ArgumentError.value(req, 'req', 'not a HTTP GET request');
  }

  // Check for malicious paths

  final urlSegments = List<String>.from(req.uri.pathSegments);

  if (urlSegments.contains('..')) {
    // Trying to go up the directory: security risk: reject request
    throw BadRequest(req, 'path contains ".."');
  }

  urlSegments.removeWhere((s) => s == '.');

  // Construct the path to the file
  //
  // Note: URLs always use '/' as the segment separator, but the file system
  // this is running on might be using something different.

  final pathComponents =
      List<String>.from(buildDir.split(Platform.pathSeparator))
        ..addAll(urlSegments);

  assert(pathComponents.first == '', "buildDir wasn't an absolute path");

  final filePath = pathComponents.join(Platform.pathSeparator);
  final file = File(filePath);

  if (!file.existsSync()) {
    _log.fine('file not found: ${file.path}');
    throw FileNotFound(req, file);
  }

  // Use the contents of the file as the HTTP response

  await _serveFileContents(file, req.response);
}

//----------------------------------------------------------------
/// Produce the HTTP response from a file.

Future<void> _serveFileContents(File file, HttpResponse resp) async {
  // Try to determine content type from filename suffix

  ContentType? contentType;

  final p = file.path;
  final dotIndex = p.lastIndexOf('.');
  if (0 < dotIndex) {
    final slashIndex = p.lastIndexOf('/');
    if (slashIndex < dotIndex) {
      // Dot is in the last segment
      var suffix = p.substring(dotIndex + 1);
      suffix = suffix.toLowerCase();
      contentType = _defaultMimeTypes[suffix];
    }
  }

  contentType = contentType ?? ContentType.binary; // default if not known

  // Produce HTTP response
  //
  // Last-Modified, Date and Content-Length helps browsers cache the contents.

  resp
    ..headers.contentType = contentType
    ..headers.add('Date', _rfc1123DateFormat(DateTime.now()))
    ..headers.add('Last-Modified', _rfc1123DateFormat(file.lastModifiedSync()))
    ..headers.add('Content-Length', (await file.length()).toString());

  await resp.addStream(file.openRead()); // contents of the file

  await resp.close();
}

//----------------------------------------------------------------
// Formats a DateTime for use in HTTP headers.
//
// Format a DateTime in the `rfc1123-date` format as defined by section 3.3.1
// of RFC 2616 <https://tools.ietf.org/html/rfc2616#section-3.3>.

String _rfc1123DateFormat(DateTime datetime) {
  final u = datetime.toUtc();
  final wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][u.weekday - 1];
  final mon = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ][u.month - 1];
  final dd = u.day.toString().padLeft(2, '0');
  final year = u.year.toString().padLeft(4, '0');
  final hh = u.hour.toString().padLeft(2, '0');
  final mm = u.minute.toString().padLeft(2, '0');
  final ss = u.second.toString().padLeft(2, '0');

  return '$wd, $dd $mon $year $hh:$mm:$ss GMT';
}

//================================================================
// Handling requests by proxying to the "webdev serve" server.

//----------------------------------------------------------------
/// Handle HTTP GET requests using assets served by "webdev serve".
///
/// Proxies the [req] through to the HTTP server at [webdevServe].
///
/// Throws [ServerUnavailable] if the HTTP server cannot be contacted.

Future<void> respondFromServe(HttpRequest req, Uri? webdevServe) async {
  if (webdevServe == null) {
    throw ArgumentError.notNull('webdevServe');
  }
  if (req.method != 'GET') {
    throw ArgumentError.value(req, 'req', 'not a HTTP GET request');
  }

  try {
    // Determine the target URI on the webdev serve to proxy the request to

    final targetUri = Uri(
        scheme: webdevServe.scheme,
        host: webdevServe.host,
        port: webdevServe.port,
        userInfo: req.uri.userInfo,
        path: req.uri.path,
        query: req.uri.query,
        fragment: req.uri.fragment.isNotEmpty ? req.uri.fragment : null);

    _log.finest('proxy request: $targetUri');

    // Pass most of the headers from the request to webdev serve.
    // Except for 'host' (which must have a new value) and 'connection' (which
    // is dropped, since the connection is not kept open).

    final targetHeaders = <String, String>{};

    req.headers.forEach((name, values) {
      String newValue;

      if (name.toLowerCase() == 'host') {
        newValue = (webdevServe.hasPort)
            ? '${webdevServe.host}:${webdevServe.port}'
            : webdevServe.host;
      } else if (name.toLowerCase() == 'connection') {
        newValue = 'close'; // do not keep-alive
      } else {
        if (values.length == 1) {
          newValue = values.first;
        } else {
          // Repeating headers are not supported by the http package, even
          // though it is permitted in HTTP
          _log.warning('multiple headers not passed to webdev serve: $name');
          throw StateError('multiple headers not supported');
        }
      }

      _log.finest('  $name: $newValue');
      targetHeaders[name] = newValue;
    });

    // Perform request on webdev serve

    final targetResponse = await http.get(targetUri, headers: targetHeaders);

    if (targetResponse.statusCode == HttpStatus.ok ||
        targetResponse.statusCode == HttpStatus.notModified) {
      _log.finest('proxy response: status ${targetResponse.statusCode}');
    } else {
      _log.fine(
          'proxy response: status ${targetResponse.statusCode}: $targetUri');
    }

    // Use the response from the target through as the response to the request

    final resp = req.response;

    for (final name in targetResponse.headers.keys) {
      String value;
      if (!_defaultResponseHeadersDiscarded.contains(name.toLowerCase())) {
        value = targetResponse.headers[name]!;
        _log.finest('  $name: $value');
        resp.headers.add(name, value);
      } else {
        _log.finest('  DISCARDED: $name: ${targetResponse.headers[name]}');
      }
    }
    resp
      ..statusCode = targetResponse.statusCode
      ..write(targetResponse.body);

    await resp.close();

    // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    String message;

    if (e is SocketException) {
      if (e.message == '' &&
          e.osError != null &&
          e.osError!.errorCode == 61 &&
          e.osError!.message == 'Connection refused') {
        // Known situation: more compact error message
        message = ': cannot connect';
      } else {
        message = '(${e.runtimeType}): $e';
      }
    } else {
      message = '(${e.runtimeType}): $e';
    }

    throw ServerUnavailable(req, message);
  }
}
