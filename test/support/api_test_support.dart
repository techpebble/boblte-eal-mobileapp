import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

Future<GetStorage> initializeTestStorage() async {
  final directory = await Directory.systemTemp.createTemp('eal-test-');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (_) async => directory.path);
  final storage = GetStorage('GetStorage', directory.path);
  await storage.initStorage;
  addTearDown(() async {
    await storage.queue.add(() async {});
    // GetStorage writes its backup after the primary write has completed.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await directory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  return storage;
}

class FakeApiAdapter implements HttpClientAdapter {
  final Object body;
  final List<RequestOptions> requests = [];

  FakeApiAdapter(this.body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> itemResponse({bool populated = true, bool? isActive}) => {
  '_id': '64a000000000000000000001',
  'itemCode': 'EAL-001',
  'name': 'Test item',
  'brand': 'Test brand',
  'market': 'local',
  'company': populated
      ? {'_id': '64a000000000000000000002', 'name': 'Test company'}
      : '64a000000000000000000002',
  'pack': populated
      ? {
          '_id': '64a000000000000000000003',
          'name': 'Test pack',
          'bottlesPerCase': 12,
        }
      : '64a000000000000000000003',
  'bottlesPerCase': 12,
  if (isActive != null) 'isActive': isActive,
};

/// Refuses one path the way `authorize` does, and answers the rest.
///
/// A role may hold usage:create without masterdata:view, which is exactly
/// this: the screen opens and the list it needs is refused.
class FakeApiRefusing implements HttpClientAdapter {
  FakeApiRefusing(
    this.refusedPath,
    this.message, {
    this.routes = const {},
    this.required_ = const ['masterdata:view'],
  });

  final String refusedPath;
  final String message;
  final Map<String, Object> routes;
  final List<String> required_;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (options.path.contains(refusedPath)) {
      return ResponseBody.fromString(
        jsonEncode({'message': message, 'required': required_}),
        403,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    final match = routes.entries
        .where((e) => options.path.contains(e.key))
        .map((e) => e.value)
        .firstOrNull;

    return ResponseBody.fromString(
      jsonEncode(match ?? const {'count': 0, 'data': []}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Answers by path, for a screen that loads more than one list.
///
/// Matches on the first key whose text appears in the request path, so
/// "companies" and "packs" can be served to the same screen.
class FakeApiRouter implements HttpClientAdapter {
  FakeApiRouter(this.routes, {this.fallback = const {'count': 0, 'data': []}});

  final Map<String, Object> routes;
  final Object fallback;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    final path = options.path;
    final match = routes.entries
        .where((e) => path.contains(e.key))
        .map((e) => e.value)
        .firstOrNull;

    return ResponseBody.fromString(
      jsonEncode(match ?? fallback),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> companyResponse({
  String id = '64a000000000000000000002',
  String name = 'Blue Ocean Beverages Pvt. Ltd.',
}) => {'_id': id, 'code': 'BOB', 'name': name, 'address': 'Industrial Estate'};

Map<String, dynamic> packResponse({
  String id = '64a000000000000000000003',
  String name = '90ml',
  int bottlesPerCase = 96,
  int pack = 90,
}) => {
  '_id': id,
  'name': name,
  'bottlesPerCase': bottlesPerCase,
  // PackSize.pack is the millilitre size, and the model types it as an int.
  'pack': pack,
};
