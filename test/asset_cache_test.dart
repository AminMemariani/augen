import 'dart:convert';
import 'dart:typed_data';

import 'package:augen/augen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('X5 AugenController asset cache', () {
    late AugenController controller;
    int bundleLoadCount = 0;
    final Map<String, Uint8List> bundleAssets = <String, Uint8List>{};

    setUp(() {
      AugenController.debugClearAssetCache();
      bundleLoadCount = 0;
      bundleAssets.clear();
      controller = AugenController(7777);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        final bytes = bundleAssets[key];
        if (bytes == null) return null;
        bundleLoadCount++;
        return ByteData.view(bytes.buffer);
      });
    });

    tearDown(() {
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      AugenController.debugClearAssetCache();
    });

    test('first load fetches from asset bundle, second hits cache', () async {
      bundleAssets['test/asset.glb'] = Uint8List.fromList(
        List<int>.generate(1024, (i) => i % 256),
      );

      final first = await controller.debugLoadAsset('test/asset.glb');
      expect(first.length, 1024);
      expect(bundleLoadCount, 1);
      expect(AugenController.debugAssetCacheEntryCount(), 1);
      expect(AugenController.debugAssetCacheSizeBytes(), 1024);

      final second = await controller.debugLoadAsset('test/asset.glb');
      expect(second.length, 1024);
      // Same bytes — cache hit, no extra bundle load.
      expect(bundleLoadCount, 1);
      expect(AugenController.debugAssetCacheEntryCount(), 1);
      expect(AugenController.debugAssetCacheSizeBytes(), 1024);
      expect(identical(first, second), isTrue);
    });

    test('different assets are cached independently with size accounting',
        () async {
      bundleAssets['a.glb'] = Uint8List(2048);
      bundleAssets['b.glb'] = Uint8List(4096);

      await controller.debugLoadAsset('a.glb');
      await controller.debugLoadAsset('b.glb');
      await controller.debugLoadAsset('a.glb'); // cache hit
      await controller.debugLoadAsset('b.glb'); // cache hit

      expect(bundleLoadCount, 2);
      expect(AugenController.debugAssetCacheEntryCount(), 2);
      expect(AugenController.debugAssetCacheSizeBytes(), 2048 + 4096);
    });

    test('cache survives across controllers (static)', () async {
      bundleAssets['shared.glb'] = Uint8List(512);

      await controller.debugLoadAsset('shared.glb');
      expect(bundleLoadCount, 1);

      // Dispose original controller, create a new one — cache should persist.
      controller.dispose();
      controller = AugenController(7778);

      await controller.debugLoadAsset('shared.glb');
      expect(bundleLoadCount, 1,
          reason: 'static cache must survive controller recreation');
      expect(AugenController.debugAssetCacheEntryCount(), 1);
    });
  });
}
