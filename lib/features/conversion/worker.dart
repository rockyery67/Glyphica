import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../destinations/formatting.dart';
import 'engine.dart';
import 'models.dart';

enum WorkKind { inspect, preview, finalRender, fit }

class WorkRequest {
  const WorkRequest(
    this.path,
    this.settings, {
    this.kind = WorkKind.finalRender,
    this.budget = 12000,
    this.codeBlock = false,
  });
  final String path;
  final ArtSettings settings;
  final WorkKind kind;
  final int budget;
  final bool codeBlock;
}

class RenderBundle {
  const RenderBundle(
    this.output,
    this.settings, {
    this.comparisons = const [],
    this.preparedThumbnail,
  });
  final ArtOutput output;
  final ArtSettings settings;
  final List<ArtOutput> comparisons;
  final Uint8List? preparedThumbnail;
}

class WorkFailure {
  const WorkFailure(this.message);
  final String message;
}

void _work((SendPort, WorkRequest) args) async {
  final (port, request) = args;
  try {
    final file = File(request.path);
    if (!await file.exists()) {
      throw const ConversionException(
        'The source image is unavailable. Your saved text can still be copied, shared, split, or exported.',
      );
    }
    if (await file.length() > ArtEngine.maxEncodedBytes) {
      throw const ConversionException(
        'This image exceeds the 24 MB input limit.',
      );
    }
    final bytes = await file.readAsBytes();
    final engine = ArtEngine();
    if (request.kind == WorkKind.inspect) {
      Isolate.exit(port, engine.inspect(bytes));
    }
    var s = request.settings;
    final prepared = engine.prepare(engine.decode(bytes), s);
    if (request.kind == WorkKind.preview) {
      s = s.copyWith(width: s.width.clamp(8, 56));
    }
    var output = engine.render(prepared, s);
    if (request.kind == WorkKind.fit) {
      // Re-render pixels at each width. Never shrink or truncate text rows.
      while (MessageFormatter.wrap(
                output.text,
                codeBlock: request.codeBlock,
              ).length >
              request.budget &&
          s.width > 8) {
        final ratio =
            request.budget /
            MessageFormatter.wrap(
              output.text,
              codeBlock: request.codeBlock,
            ).length;
        final width = (s.width * math.sqrt(ratio.clamp(0.1, 0.99)))
            .floor()
            .clamp(8, s.width - 1);
        s = s.copyWith(width: width);
        output = engine.render(prepared, s);
      }
      if (MessageFormatter.wrap(
            output.text,
            codeBlock: request.codeBlock,
          ).length >
          request.budget) {
        throw const ConversionException(
          'Even the minimum width exceeds this budget. Increase it, split into parts, or export .txt.',
        );
      }
    }
    final comparisons = request.kind == WorkKind.preview
        ? QualityLook.values
              .map(
                (look) => engine.render(
                  prepared,
                  s.withLook(look).copyWith(width: 40),
                ),
              )
              .toList()
        : <ArtOutput>[];
    Isolate.exit(port, RenderBundle(output, s, comparisons: comparisons));
  } catch (e) {
    Isolate.exit(port, WorkFailure(e.toString()));
  }
}

class CancelledConversion implements Exception {
  const CancelledConversion();
}

/// Every request owns a killable isolate. A generation token also prevents a
/// result already in flight from replacing a newer request.
class ConversionRunner {
  Isolate? _isolate;
  ReceivePort? _port;
  Completer<Object>? _pending;
  int _generation = 0;
  int get generation => _generation;

  Future<T?> run<T>(WorkRequest request) async {
    cancel();
    final generation = _generation;
    final port = ReceivePort();
    final complete = Completer<Object>();
    _port = port;
    _pending = complete;
    port.listen((value) {
      if (!complete.isCompleted) {
        if (value == null) {
          // Exit notifications may race the final message on some hosts.
          Timer(const Duration(milliseconds: 50), () {
            if (!complete.isCompleted) {
              complete.complete(
                const WorkFailure(
                  'The conversion worker stopped. Try a smaller image.',
                ),
              );
            }
          });
        } else {
          complete.complete(
            value is List
                ? WorkFailure(value.first.toString())
                : value as Object,
          );
        }
      }
    });
    try {
      final isolate = await Isolate.spawn(
        _work,
        (port.sendPort, request),
        onError: port.sendPort,
        onExit: port.sendPort,
        errorsAreFatal: true,
      );
      if (generation != _generation) {
        isolate.kill(priority: Isolate.immediate);
        return null;
      }
      _isolate = isolate;
      final result = await complete.future;
      if (generation != _generation || result is CancelledConversion) {
        return null;
      }
      if (result is WorkFailure) throw ConversionException(result.message);
      return result as T;
    } finally {
      port.close();
      if (generation == _generation) {
        _port = null;
        _pending = null;
        _isolate = null;
      }
    }
  }

  void cancel() {
    _generation++;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    if (_pending case final pending? when !pending.isCompleted) {
      pending.complete(const CancelledConversion());
    }
    _pending = null;
    _port?.close();
    _port = null;
  }
}
