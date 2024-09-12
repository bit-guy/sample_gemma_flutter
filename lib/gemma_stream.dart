import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io' show Platform, Directory;
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:rxdart/rxdart.dart';

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

final PublishSubject<String> _tokenSubject = PublishSubject<String>();

void tokenCallback(ffi.Pointer<Utf8> token) {
  _tokenSubject.add(token.toDartString());
  print(token.toDartString());
}

Stream<String> gemma(String prompt) {
  var libraryPath = path.join(Directory.current.path, 'src', 'libgemma.so');
  if (Platform.isWindows) {
    print("Windows");
    libraryPath = path.join(Directory.current.path, 'src', 'libgemma.dll');
  } else if (Platform.isMacOS) {
    print("MacOS");
    libraryPath = path.join(Directory.current.path, 'src', 'libgemma.dylib');
  } else {
    print("Linux");
    libraryPath = path.join(Directory.current.path, 'src', 'libgemma.so');
  }

  final RunDart run = ffi.DynamicLibrary.open(libraryPath)
      .lookup<ffi.NativeFunction<RunNative>>('run')
      .asFunction();

  List<String> args = [
    '',
    '--tokenizer',
    path.join(Directory.current.path, "src", "gemma-2b-sfp", "tokenizer.spm"),
    '--weights',
    path.join(Directory.current.path, "src", "gemma-2b-sfp", "2b-pt-sfp.sbs"),
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

  return _tokenSubject.stream;
}
