import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:libmpv_dart/gen/bindings.dart';

class Library {
  static late LibMPV libmpv;
  static bool loaded = false;
  static bool flagFirst = false;
  static const String _libName = 'mpv';
  static void init({String? path}) {
    try {
      final DynamicLibrary dylib = () {
        if (path != null) {
          return DynamicLibrary.open(path);
        }
        if (Platform.isMacOS || Platform.isIOS) {
          return DynamicLibrary.open('$_libName.framework/$_libName');
        }
        if (Platform.isAndroid || Platform.isLinux) {
          return DynamicLibrary.open('lib$_libName.so');
        }
        if (Platform.isWindows) {
          return DynamicLibrary.open('lib$_libName-2.dll');
        }
        throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
      }();
      Library.libmpv = LibMPV(dylib);
      loaded = true;
      flagFirst = true;
    } catch (e) {
      flagFirst = true;
      debugPrint('error loading libmpv: ${e.toString()}');
    }
  }
}
