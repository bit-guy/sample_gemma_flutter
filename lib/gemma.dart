import 'dart:ffi' as ffi;
import 'dart:io' show Platform, Directory;
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'dart:async';

typedef TokenCallback = ffi.Void Function(ffi.Pointer<Utf8>);
typedef TokenCallbackDart = void Function(ffi.Pointer<Utf8>);

// Bindings for the C library functions
typedef InitializeNative = ffi.Void Function(ffi.Pointer<Utf8> modelId,
    ffi.Int32 argc, ffi.Pointer<ffi.Pointer<Utf8>> argv);

typedef InitializeDart = void Function(
    ffi.Pointer<Utf8> modelId, int argc, ffi.Pointer<ffi.Pointer<Utf8>> argv);

typedef GenerateTextNative = ffi.Void Function(
    ffi.Pointer<Utf8> modelId,
    ffi.Pointer<Utf8> prompt,
    ffi.Pointer<ffi.NativeFunction<TokenCallback>> callback);

typedef GenerateTextDart = void Function(
    ffi.Pointer<Utf8> modelId,
    ffi.Pointer<Utf8> prompt,
    ffi.Pointer<ffi.NativeFunction<TokenCallback>> callback);

typedef CleanupNative = ffi.Void Function(ffi.Pointer<Utf8> modelId);

typedef CleanupDart = void Function(ffi.Pointer<Utf8> modelId);

// Global variable to hold the current callback function
void Function(String)? _currentCallback;
final gemmaController = StreamController<String>();

final gemmaMap = {
  "gemma-2b-sfp": {
    "tokenizer": path.join(
        Directory.current.path, "src", "gemma-2b-sfp", "tokenizer.spm"),
    "weights": path.join(
        Directory.current.path, "src", "gemma-2b-sfp", "2b-pt-sfp.sbs"),
    "weight_type": "sfp",
    "model": "2b-pt",
    "max_generated_tokens": "8",
  },
  "gemma-2b-it-sfp": {
    "tokenizer": path.join(
        Directory.current.path, "src", "gemma-2b-it-sfp", "tokenizer.spm"),
    "weights": path.join(
        Directory.current.path, "src", "gemma-2b-it-sfp", "2b-it-sfp.sbs"),
    "weight_type": "sfp",
    "model": "2b-it",
    "max_generated_tokens": "16",
  },
  "recurrentgemma-2b-it-sfp-cpp": {
    "tokenizer": path.join(Directory.current.path, "src",
        "recurrentgemma-2b-it-sfp-cpp", "tokenizer.spm"),
    "weights": path.join(Directory.current.path, "src",
        "recurrentgemma-2b-it-sfp-cpp", "2b-it-sfp.sbs"),
    "weight_type": "sfp",
    "model": "gr2b-it",
    "max_generated_tokens": "16",
  },
};

class GemmaModel {
  late final InitializeDart _initializeModel;
  late final GenerateTextDart _generateText;
  late final CleanupDart _cleanupModel;

  late final ffi.Pointer<ffi.Pointer<Utf8>> _argv;
  final List<String> _args;
  final String _modelId;

  GemmaModel(this._modelId)
      : _args = [
          '',
          '--tokenizer',
          gemmaMap[_modelId]?['tokenizer'] ?? '',
          '--weights',
          gemmaMap[_modelId]?['weights'] ?? '',
          '--weight_type',
          gemmaMap[_modelId]?['weight_type'] ?? '',
          '--model',
          gemmaMap[_modelId]?['model'] ?? '',
          '--max_generated_tokens',
          gemmaMap[_modelId]?['max_generated_tokens'] ?? '',
        ] {
    print("Initiated model $_modelId");
    _initializeLibrary();
    _initializeArgv();
    _initializeModelInstance();
    print("Finish initiated");
  }

  void _initializeLibrary() {
    var libraryPath = path.join(Directory.current.path, 'src', 'libgemma.so');
    if (Platform.isWindows) {
      libraryPath = path.join(Directory.current.path, 'src', 'libgemma.dll');
    } else if (Platform.isMacOS) {
      libraryPath = path.join(Directory.current.path, 'src', 'libgemma.dylib');
    }

    final dynamicLibrary = ffi.DynamicLibrary.open(libraryPath);

    _initializeModel = dynamicLibrary
        .lookup<ffi.NativeFunction<InitializeNative>>('initialize_model')
        .asFunction();

    _generateText = dynamicLibrary
        .lookup<ffi.NativeFunction<GenerateTextNative>>('generate_text')
        .asFunction();

    _cleanupModel = dynamicLibrary
        .lookup<ffi.NativeFunction<CleanupNative>>('cleanup_model')
        .asFunction();
  }

  void _initializeArgv() {
    _argv = calloc(_args.length);
    for (int i = 0; i < _args.length; i++) {
      _argv[i] = _args[i].toNativeUtf8();
    }
  }

  // Initialize the model
  void _initializeModelInstance() {
    final modelIdNative = _modelId.toNativeUtf8();
    _initializeModel(modelIdNative, _args.length, _argv);
    calloc.free(modelIdNative);
  }

  // Static callback function
  static void _tokenCallback(ffi.Pointer<Utf8> token) {
    if (_currentCallback != null) {
      final tokenString = token.toDartString();
      _currentCallback!(tokenString);
      gemmaController.add(tokenString);
    }
  }

  // Text generation
  void generateResponse(String prompt, void Function(String) onToken) {
    _currentCallback = onToken;

    final callbackPointer =
        ffi.Pointer.fromFunction<TokenCallback>(_tokenCallback);
    final promptNative = prompt.toNativeUtf8();
    final modelIdNative = _modelId.toNativeUtf8();

    _generateText(modelIdNative, promptNative, callbackPointer);

    calloc.free(promptNative);
    calloc.free(modelIdNative);
    _currentCallback = null;
  }

  Future<void> generateResponseAsync(
    String prompt,
    void Function(String) onToken,
  ) async {
    _currentCallback = onToken;

    final callbackPointer =
        ffi.Pointer.fromFunction<TokenCallback>(_tokenCallback);
    final promptNative = prompt.toNativeUtf8();
    final modelIdNative = _modelId.toNativeUtf8();

    // Run the generation asynchronously to avoid blocking the main thread
    await Future(() {
      _generateText(modelIdNative, promptNative, callbackPointer);
    });

    calloc.free(promptNative);
    calloc.free(modelIdNative);
    _currentCallback = null;
  }

  // Synchronous text generation
  List<String> generateResponseBatch(String prompt) {
    final tokens = <String>[];
    generateResponse(prompt, (token) => tokens.add(token));
    return tokens;
  }

  // Cleanup the model
  void cleanupModel() {
    final modelIdNative = _modelId.toNativeUtf8();
    _cleanupModel(modelIdNative);
    calloc.free(modelIdNative);
  }

  void dispose() {
    for (int i = 0; i < _args.length; i++) {
      calloc.free(_argv[i]);
    }
    calloc.free(_argv);
  }
}

// Usage example
void main() async {
  final model1 = GemmaModel("model_1");

  model1.generateResponse("Hello, how are you?", (token) {
    print(token);
  });

  print("\n---\n");

  await model1.generateResponseAsync("1+1=", (token) {
    print(token);
  });

  // Cleanup models
  model1.cleanupModel();
  model1.dispose();
}
