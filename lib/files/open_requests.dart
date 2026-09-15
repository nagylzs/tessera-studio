import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A file the operating system asked us to open ("Open with…", the share
/// sheet), as delivered by the platform side: see
/// `android/.../MainActivity.kt`, which copies the content stream to the
/// cache and reports these events.
sealed class OpenRequest {
  const OpenRequest(this.name);

  /// The display name the sender uses; carries the extension.
  final String name;
}

/// The platform side has started copying the file.
final class OpenStarted extends OpenRequest {
  const OpenStarted(super.name);
}

/// The file is at [path], ready to be loaded under [name].
final class OpenReady extends OpenRequest {
  const OpenReady(super.name, this.path);

  final String path;
}

/// The platform side could not read the file.
final class OpenRequestFailed extends OpenRequest {
  const OpenRequestFailed(super.name, this.error);

  final String error;
}

/// Source of [OpenRequest]s. Registered in get_it; a no-op everywhere
/// but Android for now.
abstract interface class OpenRequests {
  Stream<OpenRequest> get requests;

  /// The implementation for the current platform.
  static OpenRequests forPlatform() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? const ChannelOpenRequests()
      : const NoOpenRequests();
}

final class NoOpenRequests implements OpenRequests {
  const NoOpenRequests();

  @override
  Stream<OpenRequest> get requests => const Stream.empty();
}

/// Listens on the platform event channel. Events raised before the
/// subscription are queued on the platform side, so subscribing late is
/// fine, but subscribe once: the queue is flushed to the first listener.
final class ChannelOpenRequests implements OpenRequests {
  const ChannelOpenRequests();

  static const channel = EventChannel('eu.nagylzs.tessera_studio/open');

  @override
  Stream<OpenRequest> get requests => channel.receiveBroadcastStream().map(
    (event) => decode((event as Map).cast<String, Object?>()),
  );

  /// Turns one platform event into a request; throws [FormatException]
  /// on anything unexpected.
  static OpenRequest decode(Map<String, Object?> event) {
    final name = event['name'] as String? ?? 'file';
    return switch (event['event']) {
      'started' => OpenStarted(name),
      'ready' => OpenReady(name, event['path'] as String),
      'failed' => OpenRequestFailed(name, event['error'] as String? ?? ''),
      final other => throw FormatException('unknown open event: $other'),
    };
  }
}
