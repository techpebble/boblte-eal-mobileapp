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
