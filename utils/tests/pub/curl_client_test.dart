// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library curl_client_test;

import 'dart:io';
import 'dart:isolate';
import 'dart:json' as json;
import 'dart:uri';

import '../../../pkg/unittest/lib/unittest.dart';
import '../../../pkg/http/lib/http.dart' as http;
import '../../pub/curl_client.dart';
import '../../pub/io.dart';
import '../../pub/utils.dart';

// TODO(rnystrom): All of the code from here to the first "---..." line was
// copied from pkg/http/test/utils.dart and pkg/http/lib/src/utils.dart. It's
// copied here because http/test/utils.dart is now using "package:" imports and
// this is not. You cannot mix those because you end up with duplicate copies of
// the same library in memory. Since curl_client is going away soon anyway, I'm
// just copying the code here. Delete all of this when curl client is removed.

/// Returns the [Encoding] that corresponds to [charset]. Throws a
/// [FormatException] if no [Encoding] was found that corresponds to [charset].
/// [charset] may not be null.
Encoding requiredEncodingForCharset(String charset) {
  var encoding = _encodingForCharset(charset);
  if (encoding != null) return encoding;
  throw new FormatException('Unsupported encoding "$charset".');
}

/// Returns the [Encoding] that corresponds to [charset]. Returns null if no
/// [Encoding] was found that corresponds to [charset]. [charset] may not be
/// null.
Encoding _encodingForCharset(String charset) {
  charset = charset.toLowerCase();
  if (charset == 'ascii' || charset == 'us-ascii') return Encoding.ASCII;
  if (charset == 'utf-8') return Encoding.UTF_8;
  if (charset == 'iso-8859-1') return Encoding.ISO_8859_1;
  return null;
}

/// Converts [bytes] into a [String] according to [encoding].
String decodeString(List<int> bytes, Encoding encoding) {
  // TODO(nweiz): implement this once issue 6284 is fixed.
  return new String.fromCharCodes(bytes);
}

/// The current server instance.
HttpServer _server;

/// The URL for the current server instance.
Uri get serverUrl => Uri.parse('http://localhost:${_server.port}');

/// A dummy URL for constructing requests that won't be sent.
Uri get dummyUrl => Uri.parse('http://dartlang.org/');

/// Starts a new HTTP server.
void startServer() {
  _server = new HttpServer();

  _server.addRequestHandler((request) => request.path == '/error',
      (request, response) {
    response.statusCode = 400;
    response.contentLength = 0;
    response.outputStream.close();
  });

  _server.addRequestHandler((request) => request.path == '/loop',
      (request, response) {
    var n = int.parse(Uri.parse(request.uri).query);
    response.statusCode = 302;
    response.headers.set('location',
        serverUrl.resolve('/loop?${n + 1}').toString());
    response.contentLength = 0;
    response.outputStream.close();
  });

  _server.addRequestHandler((request) => request.path == '/redirect',
      (request, response) {
    response.statusCode = 302;
    response.headers.set('location', serverUrl.resolve('/').toString());
    response.contentLength = 0;
    response.outputStream.close();
  });

  _server.defaultRequestHandler = (request, response) {
    consumeInputStream(request.inputStream).then((requestBodyBytes) {
      response.statusCode = 200;
      response.headers.contentType = new ContentType("application", "json");

      var requestBody;
      if (requestBodyBytes.isEmpty) {
        requestBody = null;
      } else if (request.headers.contentType.charset != null) {
        var encoding = requiredEncodingForCharset(
            request.headers.contentType.charset);
        requestBody = decodeString(requestBodyBytes, encoding);
      } else {
        requestBody = requestBodyBytes;
      }

      var content = {
        'method': request.method,
        'path': request.path,
        'headers': {}
      };
      if (requestBody != null) content['body'] = requestBody;
      request.headers.forEach((name, values) {
        // These headers are automatically generated by dart:io, so we don't
        // want to test them here.
        if (name == 'cookie' || name == 'host') return;

        content['headers'][name] = values;
      });

      var outputEncoding;
      var encodingName = request.queryParameters['response-encoding'];
      if (encodingName != null) {
        outputEncoding = requiredEncodingForCharset(encodingName);
      } else {
        outputEncoding = Encoding.ASCII;
      }

      var body = json.stringify(content);
      response.contentLength = body.length;
      response.outputStream.writeString(body, outputEncoding);
      response.outputStream.close();
    });
  };

  _server.listen("127.0.0.1", 0);
}

/// Stops the current HTTP server.
void stopServer() {
  _server.close();
  _server = null;
}

/// A matcher that matches JSON that parses to a value that matches the inner
/// matcher.
Matcher parse(matcher) => new _Parse(matcher);

class _Parse extends BaseMatcher {
  final Matcher _matcher;

  _Parse(this._matcher);

  bool matches(item, MatchState matchState) {
    if (item is! String) return false;

    var parsed;
    try {
      parsed = json.parse(item);
    } catch (e) {
      return false;
    }

    return _matcher.matches(parsed, matchState);
  }

  Description describe(Description description) {
    return description.add('parses to a value that ')
      .addDescriptionOf(_matcher);
  }
}

// TODO(nweiz): remove this once it's built in to unittest (issue 7922).
/// A matcher for StateErrors.
const isStateError = const _StateError();

/// A matcher for functions that throw StateError.
const Matcher throwsStateError =
    const Throws(isStateError);

class _StateError extends TypeMatcher {
  const _StateError() : super("StateError");
  bool matches(item, MatchState matchState) => item is StateError;
}

/// A matcher for HttpExceptions.
const isHttpException = const _HttpException();

/// A matcher for functions that throw HttpException.
const Matcher throwsHttpException =
    const Throws(isHttpException);

class _HttpException extends TypeMatcher {
  const _HttpException() : super("HttpException");
  bool matches(item, MatchState matchState) => item is HttpException;
}

/// A matcher for RedirectLimitExceededExceptions.
const isRedirectLimitExceededException =
    const _RedirectLimitExceededException();

/// A matcher for functions that throw RedirectLimitExceededException.
const Matcher throwsRedirectLimitExceededException =
    const Throws(isRedirectLimitExceededException);

class _RedirectLimitExceededException extends TypeMatcher {
  const _RedirectLimitExceededException() :
      super("RedirectLimitExceededException");

  bool matches(item, MatchState matchState) =>
    item is RedirectLimitExceededException;
}

// ----------------------------------------------------------------------------

void main() {
  setUp(startServer);
  tearDown(stopServer);

  test('head', () {
    expect(new CurlClient().head(serverUrl).then((response) {
      expect(response.statusCode, equals(200));
      expect(response.body, equals(''));
    }), completes);
  });

  test('get', () {
    expect(new CurlClient().get(serverUrl, headers: {
      'X-Random-Header': 'Value',
      'X-Other-Header': 'Other Value'
    }).then((response) {
      expect(response.statusCode, equals(200));
      expect(response.body, parse(equals({
        'method': 'GET',
        'path': '/',
        'headers': {
          'x-random-header': ['Value'],
          'x-other-header': ['Other Value']
        },
      })));
    }), completes);
  });

  test('post', () {
    expect(new CurlClient().post(serverUrl, headers: {
      'X-Random-Header': 'Value',
      'X-Other-Header': 'Other Value'
    }, fields: {
      'some-field': 'value',
      'other-field': 'other value'
    }).then((response) {
      expect(response.statusCode, equals(200));
      expect(response.body, parse(equals({
        'method': 'POST',
        'path': '/',
        'headers': {
          'content-type': [
            'application/x-www-form-urlencoded; charset=UTF-8'
          ],
          'content-length': ['40'],
          'x-random-header': ['Value'],
          'x-other-header': ['Other Value']
        },
        'body': 'some-field=value&other-field=other+value'
      })));
    }), completes);
  });

  test('post without fields', () {
    expect(new CurlClient().post(serverUrl, headers: {
      'X-Random-Header': 'Value',
      'X-Other-Header': 'Other Value',
      'Content-Type': 'text/plain'
    }).then((response) {
      expect(response.statusCode, equals(200));
      expect(response.body, parse(equals({
        'method': 'POST',
        'path': '/',
        'headers': {
          'content-type': ['text/plain'],
          'x-random-header': ['Value'],
          'x-other-header': ['Other Value']
        }
      })));
    }), completes);
  });

  test('put', () {
    expect(new CurlClient().put(serverUrl, headers: {
      'X-Random-Header': 'Value',
      'X-Other-Header': 'Other Value'
    }, fields: {
      'some-field': 'value',
      'other-field': 'other value'
    }).then((response) {
      expect(response.statusCode, equals(200));
      expect(response.body, parse(equals({
        'method': 'PUT',
        'path': '/',
        'headers': {
          'content-type': [
            'application/x-www-form-urlencoded; charset=UTF-8'
          ],
          'content-length': ['40'],
          'x-random-header': ['Value'],
          'x-other-header': ['Other Value']
        },
        'body': 'some-field=value&other-field=other+value'
      })));
    }), completes);
  });

  test('put without fields', () {
    expect(new CurlClient().put(serverUrl, headers: {
      'X-Random-Header': 'Value',
      'X-Other-Header': 'Other Value',
      'Content-Type': 'text/plain'
    }).then((response) {
      expect(response.statusCode, equals(200));
      expect(response.body, parse(equals({
        'method': 'PUT',
        'path': '/',
        'headers': {
          'content-type': ['text/plain'],
          'x-random-header': ['Value'],
          'x-other-header': ['Other Value']
        }
      })));
    }), completes);
  });

  test('delete', () {
    expect(new CurlClient().delete(serverUrl, headers: {
      'X-Random-Header': 'Value',
      'X-Other-Header': 'Other Value'
    }).then((response) {
      expect(response.statusCode, equals(200));
      expect(response.body, parse(equals({
        'method': 'DELETE',
        'path': '/',
        'headers': {
          'x-random-header': ['Value'],
          'x-other-header': ['Other Value']
        }
      })));
    }), completes);
  });

  test('read', () {
    expect(new CurlClient().read(serverUrl, headers: {
      'X-Random-Header': 'Value',
      'X-Other-Header': 'Other Value'
    }), completion(parse(equals({
      'method': 'GET',
      'path': '/',
      'headers': {
        'x-random-header': ['Value'],
        'x-other-header': ['Other Value']
      },
    }))));
  });

  test('read throws an error for a 4** status code', () {
    expect(new CurlClient().read(serverUrl.resolve('/error')),
        throwsHttpException);
  });

  test('readBytes', () {
    var future = new CurlClient().readBytes(serverUrl, headers: {
      'X-Random-Header': 'Value',
      'X-Other-Header': 'Other Value'
    }).then((bytes) => new String.fromCharCodes(bytes));

    expect(future, completion(parse(equals({
      'method': 'GET',
      'path': '/',
      'headers': {
        'x-random-header': ['Value'],
        'x-other-header': ['Other Value']
      },
    }))));
  });

  test('readBytes throws an error for a 4** status code', () {
    expect(new CurlClient().readBytes(serverUrl.resolve('/error')),
        throwsHttpException);
  });

  test('#send a StreamedRequest', () {
    var client = new CurlClient();
    var request = new http.StreamedRequest("POST", serverUrl);
    request.headers[HttpHeaders.CONTENT_TYPE] =
      'application/json; charset=utf-8';

    var future = client.send(request).then((response) {
      expect(response.statusCode, equals(200));
      return response.stream.bytesToString();
    }).whenComplete(client.close);

    expect(future, completion(parse(equals({
      'method': 'POST',
      'path': '/',
      'headers': {
        'content-type': ['application/json; charset=utf-8'],
        'transfer-encoding': ['chunked']
      },
      'body': '{"hello": "world"}'
    }))));

    request.sink.add('{"hello": "world"}'.charCodes);
    request.sink.close();
  });

  test('with one redirect', () {
    var url = serverUrl.resolve('/redirect');
    expect(new CurlClient().get(url).then((response) {
      expect(response.statusCode, equals(200));
      expect(response.body, parse(equals({
        'method': 'GET',
        'path': '/',
        'headers': {}
      })));
    }), completes);
  });

  test('with too many redirects', () {
    expect(new CurlClient().get(serverUrl.resolve('/loop?1')),
        throwsRedirectLimitExceededException);
  });

  test('with a generic failure', () {
    expect(new CurlClient().get('url fail'),
        throwsHttpException);
  });

  test('with one redirect via HEAD', () {
    var url = serverUrl.resolve('/redirect');
    expect(new CurlClient().head(url).then((response) {
      expect(response.statusCode, equals(200));
    }), completes);
  });

  test('with too many redirects via HEAD', () {
    expect(new CurlClient().head(serverUrl.resolve('/loop?1')),
        throwsRedirectLimitExceededException);
  });

  test('with a generic failure via HEAD', () {
    expect(new CurlClient().head('url fail'),
        throwsHttpException);
  });

  test('without following redirects', () {
    var request = new http.Request('GET', serverUrl.resolve('/redirect'));
    request.followRedirects = false;
    expect(new CurlClient().send(request).then(http.Response.fromStream)
        .then((response) {
      expect(response.statusCode, equals(302));
      expect(response.isRedirect, true);
    }), completes);
  });
}