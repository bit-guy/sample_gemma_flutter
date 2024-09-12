import 'dart:ffi' as ffi;
import 'dart:io' show Platform, Directory;
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

// Define the Dart signature for the callback
typedef TokenCallback = ffi.Void Function(ffi.Pointer<Utf8>);
typedef TokenCallbackDart = void Function(ffi.Pointer<Utf8>);

typedef RunNative = ffi.Void Function(
    ffi.Int32 argc,
    ffi.Pointer<ffi.Pointer<Utf8>> argv,
    ffi.Pointer<Utf8> prompt,
    ffi.Pointer<ffi.NativeFunction<TokenCallback>> callback);

typedef RunDart = void Function(
    int argc,
    ffi.Pointer<ffi.Pointer<Utf8>> argv,
    ffi.Pointer<Utf8> prompt,
    ffi.Pointer<ffi.NativeFunction<TokenCallback>> callback);

// // The callback function that will receive streamed tokens
// void tokenCallback(ffi.Pointer<Utf8> token) {
//   print('Received token: ${token.toDartString()}');
// }

void gemma(String prompt, TokenCallbackDart tokenCallback) {
  var libraryPath = '';
  if (Platform.isWindows) {
    libraryPath = path.join(Directory.current.path, 'src', 'libgemma.dll');
  } else if (Platform.isMacOS) {
    libraryPath = path.join(Directory.current.path, 'src', 'libgemma.dylib');
  } else {
    libraryPath = path.join(Directory.current.path, 'src', 'libgemma.so');
  }

  // Look up the C function 'hello_world'
  final RunDart run = ffi.DynamicLibrary.open(libraryPath)
      .lookup<ffi.NativeFunction<RunNative>>('run')
      .asFunction();

  // Define the arguments
  List args = [
    '',
    '--tokenizer',
    'C:\\Users\\guy_thebitstudio\\Projects\\gemmacpp_flutter\\hello_world\\gemma.cpp\\gemma-2b-sfp\\tokenizer.spm',
    '--weights',
    'C:\\Users\\guy_thebitstudio\\Projects\\gemmacpp_flutter\\hello_world\\2b-pt-sfp.sbs',
    '--weight_type',
    'sfp',
    '--model',
    '2b-pt',
    '--max_generated_tokens',
    '8',
  ];

  final ffi.Pointer<ffi.Pointer<Utf8>> argv = calloc(args.length);
  for (int i = 0; i < args.length; i++) {
    argv[i] = args[i].toNativeUtf8();
  }

  final ffi.Pointer<ffi.NativeFunction<TokenCallback>> callbackPointer =
      ffi.Pointer.fromFunction(tokenCallback);

  final ffi.Pointer<Utf8> promptNative = prompt.toNativeUtf8();

  run(args.length, argv, promptNative, callbackPointer);

  for (int i = 0; i < args.length; i++) {
    calloc.free(argv[i]);
  }
  calloc.free(argv);
}
