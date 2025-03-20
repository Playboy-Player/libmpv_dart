import 'dart:async';
import 'dart:ffi';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:ffi/ffi.dart';

import 'package:libmpv_dart/gen/bindings.dart';
import 'package:libmpv_dart/library.dart';
import 'package:libmpv_dart/video/audio_params.dart';
import 'package:libmpv_dart/video/video_params.dart';

typedef WakeUpCallback = Void Function(Pointer<mpv_handle>);
typedef WakeUpNativeCallable = NativeCallable<WakeUpCallback>;
typedef EventCallback = Future<void> Function(Pointer<mpv_event>);

MethodChannel _channel = const MethodChannel('libmpv_dart');

class Player {
  late Pointer<mpv_handle> ctx;
  int get handle => ctx.address;
  bool _videoOutput = false;

  Player(
    Map<String, String> options, {
    bool initialize = true,
    bool videoOutput = false,
  }) {
    if (!Library.loaded) {
      if (!Library.flagFirst) {
        Library.init();
      } else {
        throw Exception('libmpv is not loaded!');
      }
    }
    ctx = Library.libmpv.mpv_create();
    for (var entry in options.entries) {
      final key = entry.key.toNativeUtf8();
      final value = entry.value.toNativeUtf8();
      int error =
          Library.libmpv.mpv_set_option_string(ctx, key.cast(), value.cast());
      if (error != mpv_error.MPV_ERROR_SUCCESS.value) {
        throw Exception(
          Library.libmpv.mpv_error_string(error).cast<Utf8>().toDartString(),
        );
      }
      calloc.free(key);
      calloc.free(value);
    }
    if (initialize) {
      init(videoOutput: videoOutput);
    }
  }

  void init({bool videoOutput = false}) {
    int error = Library.libmpv.mpv_initialize(ctx);
    if (error != mpv_error.MPV_ERROR_SUCCESS.value) {
      throw Exception(
        Library.libmpv.mpv_error_string(error).cast<Utf8>().toDartString(),
      );
    }

    <String, mpv_format>{
      'pause': mpv_format.MPV_FORMAT_FLAG,
      'time-pos': mpv_format.MPV_FORMAT_DOUBLE,
      'duration': mpv_format.MPV_FORMAT_DOUBLE,
      'volume': mpv_format.MPV_FORMAT_DOUBLE,
      'speed': mpv_format.MPV_FORMAT_DOUBLE,
      'video-out-params': mpv_format.MPV_FORMAT_NODE,
      'audio-params': mpv_format.MPV_FORMAT_NODE,
    }.forEach(
      (property, format) {
        final name = property.toNativeUtf8();
        Library.libmpv.mpv_observe_property(
          ctx,
          0,
          name.cast(),
          format,
        );
        calloc.free(name);
      },
    );

    // TODO: dispose
    final nativeCallable = WakeUpNativeCallable.listener(_mpvCallback);
    final nativeFunction = nativeCallable.nativeFunction;
    Library.libmpv
        .mpv_set_wakeup_callback(ctx, nativeFunction.cast(), ctx.cast());

    _videoOutput = videoOutput;
    if (videoOutput) {
      initVO();
    }
  }

  Future<void> initVO() async {
    setPropertyString('vo', 'libmpv');
    setPropertyString('hwdec', 'auto');
    setPropertyString('vid', 'auto');

    final textureId = await _channel.invokeMethod(
      'VOCreate',
      {
        'handle': handle,
        'hwdec': true,
      },
    );

    id.value = textureId;
  }

  void observeProperty(
    String property,
    mpv_format format, {
    int propertyId = 0,
  }) {
    final name = property.toNativeUtf8();
    Library.libmpv.mpv_observe_property(
      ctx,
      propertyId,
      name.cast(),
      format,
    );
    calloc.free(name);
    _observedProperties.add(property);
  }

  // use the propertyId passed in observeProperty Function to remove
  // (optional) pass the propertyName to cancel the observation in event handler
  void unObserveProperty(int propertyId, {String? propertyName}) {
    Library.libmpv.mpv_unobserve_property(
      ctx,
      0,
    );
    if (propertyName != null) {
      _observedProperties.remove(propertyName);
    }
  }

  // if the width/height is null, the output size will be same as video size
  Future<void> setOutputSize({int? width, int? height}) async {
    if (!_videoOutput) return;
    final textureId = await _channel.invokeMethod(
      'VOSetSize',
      {
        'handle': handle,
        'width': (width ?? videoParams.value.dw),
        'height': (height ?? videoParams.value.dh),
      },
    );

    id.value = textureId;
  }

  void command(List<String> args) {
    var pointers = args.map((str) => str.toNativeUtf8()).toList();
    final arr = calloc<Pointer<Utf8>>(sizeOf<Pointer<Utf8>>() * args.length);

    for (int i = 0; i < args.length; i++) {
      (arr + i).value = pointers[i];
    }
    int error = Library.libmpv.mpv_command(ctx, arr.cast());
    if (error != mpv_error.MPV_ERROR_SUCCESS.value) {
      debugPrint(
        Library.libmpv.mpv_error_string(error).cast<Utf8>().toDartString(),
      );
    }
    calloc.free(arr);
    pointers.forEach(calloc.free);
  }

  void commandNode(Pointer<mpv_node> node1, Pointer<mpv_node> node2) {
    int error = Library.libmpv.mpv_command_node(ctx, node1, node2);
    if (error != mpv_error.MPV_ERROR_SUCCESS.value) {
      debugPrint(
          Library.libmpv.mpv_error_string(error).cast<Utf8>().toDartString());
    }
  }

  void _setProperty(
    String name,
    mpv_format format,
    Pointer<Void> data,
  ) {
    final namePtr = name.toNativeUtf8();

    int error = Library.libmpv.mpv_set_property(
      ctx,
      namePtr.cast(),
      format,
      data,
    );
    if (error != mpv_error.MPV_ERROR_SUCCESS.value) {
      debugPrint(
        Library.libmpv.mpv_error_string(error).cast<Utf8>().toDartString(),
      );
    }
    calloc.free(namePtr);
  }

  void setPropertyFlag(String name, bool value) {
    final ptr = calloc<Bool>(1)..value = value;
    _setProperty(
      name,
      mpv_format.MPV_FORMAT_FLAG,
      ptr.cast(),
    );
    calloc.free(ptr);
  }

  void setPropertyDouble(
    String name,
    double value,
  ) {
    final ptr = calloc<Double>(1)..value = value;
    _setProperty(
      name,
      mpv_format.MPV_FORMAT_DOUBLE,
      ptr.cast(),
    );
    calloc.free(ptr);
  }

  void setPropertyInt64(
    String name,
    int value,
  ) {
    final ptr = calloc<Int64>(1)..value = value;
    _setProperty(
      name,
      mpv_format.MPV_FORMAT_INT64,
      ptr.cast(),
    );
    calloc.free(ptr);
  }

  void setPropertyString(
    String name,
    String value,
  ) {
    final string = value.toNativeUtf8();
    final ptr = calloc<Pointer<Void>>(1);
    ptr.value = Pointer.fromAddress(string.address);
    _setProperty(
      name,
      mpv_format.MPV_FORMAT_STRING,
      ptr.cast(),
    );
    calloc.free(ptr);
    calloc.free(string);
  }

  void setPropertyNode(String name, Pointer<mpv_node> node) {
    final namePtr = name.toNativeUtf8();
    _setProperty(name, mpv_format.MPV_FORMAT_NODE, node.cast());
    calloc.free(namePtr);
  }

  @Deprecated('It is recommended to use setProperty with typed arguments')
  void setProperty(String name, dynamic value) {
    if (value is double) {
      setPropertyDouble(name, value);
    } else if (value is int) {
      setPropertyInt64(name, value);
    } else if (value is String) {
      setPropertyString(name, value);
    } else if (value is bool) {
      setPropertyFlag(name, value);
    } else if (value is Pointer<mpv_node>) {
      setPropertyNode(name, value);
    } else {
      throw Exception('Invalid value type');
    }
  }

  void setOptionAll(
    String name,
    mpv_format format,
    Pointer<Void> data,
  ) {
    final namePtr = name.toNativeUtf8();

    int error = Library.libmpv.mpv_set_option(
      ctx,
      namePtr.cast(),
      format,
      data,
    );
    if (error != mpv_error.MPV_ERROR_SUCCESS.value) {
      throw Exception(
          Library.libmpv.mpv_error_string(error).cast<Utf8>().toDartString());
    }
    calloc.free(namePtr);
  }

  void setOptionFlag(String name, bool value) {
    final ptr = calloc<Bool>(1)..value = value;
    setOptionAll(
      name,
      mpv_format.MPV_FORMAT_FLAG,
      ptr.cast(),
    );
    calloc.free(ptr);
  }

  void setOptionDouble(
    String name,
    double value,
  ) {
    final ptr = calloc<Double>(1)..value = value;
    setOptionAll(
      name,
      mpv_format.MPV_FORMAT_DOUBLE,
      ptr.cast(),
    );
    calloc.free(ptr);
  }

  void setOptionInt64(
    String name,
    int value,
  ) {
    final ptr = calloc<Int64>(1)..value = value;
    setOptionAll(
      name,
      mpv_format.MPV_FORMAT_INT64,
      ptr.cast(),
    );
    calloc.free(ptr);
  }

  void setOptionString(
    String name,
    String value,
  ) {
    final string = value.toNativeUtf8();
    final ptr = calloc<Pointer<Void>>(1);
    ptr.value = Pointer.fromAddress(string.address);
    setOptionAll(
      name,
      mpv_format.MPV_FORMAT_STRING,
      ptr.cast(),
    );
    calloc.free(ptr);
    calloc.free(string);
  }

  void setOptionNode(String name, Pointer<mpv_node> node) {
    final namePtr = name.toNativeUtf8();
    setOptionAll(name, mpv_format.MPV_FORMAT_NODE, node.cast());
    calloc.free(namePtr);
  }

  void setOption(String name, dynamic value) {
    if (value is double) {
      setOptionDouble(name, value);
    } else if (value is int) {
      setOptionInt64(name, value);
    } else if (value is String) {
      setOptionString(name, value);
    } else if (value is bool) {
      setOptionFlag(name, value);
    } else if (value is Pointer<mpv_node>) {
      setOptionNode(name, value);
    } else {
      debugPrint('Value type is not supported');
    }
  }

  Pointer<mpv_event> waitEvent(double timeout) {
    Pointer<mpv_event> event = Library.libmpv.mpv_wait_event(ctx, timeout);
    if (event.ref.error != mpv_error.MPV_ERROR_SUCCESS.value) {
      debugPrint(
        Library.libmpv
            .mpv_error_string(event.ref.error)
            .cast<Utf8>()
            .toDartString(),
      );
    }

    return event;
  }

  void destroy() {
    if (_videoOutput) {
      _channel.invokeMethod(
        'VODispose',
        {'handle': handle},
      );
    }
    Library.libmpv.mpv_destroy(ctx);
  }

  // texture id for video rendering
  final ValueNotifier<int> id = ValueNotifier<int>(0);
  final ValueNotifier<VideoParams> videoParams =
      ValueNotifier(const VideoParams());
  final ValueNotifier<AudioParams> audioParams =
      ValueNotifier(const AudioParams());
  final ValueNotifier<bool> paused = ValueNotifier<bool>(true);
  final ValueNotifier<int> position = ValueNotifier<int>(0);
  final ValueNotifier<int> duration = ValueNotifier<int>(0);
  final ValueNotifier<double> volume = ValueNotifier<double>(100);
  final ValueNotifier<double> speed = ValueNotifier<double>(1.0);

  Function(String, mpv_format)? propertyChangedCallback;
  final Set<String> _observedProperties = {};

  void _mpvCallback(Pointer<mpv_handle> ctx) async {
    while (true) {
      final event = Library.libmpv.mpv_wait_event(ctx, 0);
      if (event == nullptr) return;
      if (event.ref.event_id == mpv_event_id.MPV_EVENT_NONE) return;
      await _mpvEventHandler(event);
    }
  }

  Future<void> _mpvEventHandler(Pointer<mpv_event> event) async {
    if (event.ref.event_id == mpv_event_id.MPV_EVENT_PROPERTY_CHANGE) {
      final prop = event.ref.data.cast<mpv_event_property>();
      final propName = prop.ref.name.cast<Utf8>().toDartString();
      if (propName == 'pause' &&
          prop.ref.format == mpv_format.MPV_FORMAT_FLAG) {
        paused.value = prop.ref.data.cast<Int8>().value != 0;
      } else if (propName == 'duration' &&
          prop.ref.format == mpv_format.MPV_FORMAT_DOUBLE) {
        duration.value = prop.ref.data.cast<Double>().value ~/ 1;
      } else if (propName == 'volume' &&
          prop.ref.format == mpv_format.MPV_FORMAT_DOUBLE) {
        volume.value = prop.ref.data.cast<Double>().value;
      } else if (propName == 'speed' &&
          prop.ref.format == mpv_format.MPV_FORMAT_DOUBLE) {
        speed.value = prop.ref.data.cast<Double>().value;
      } else if (propName == 'time-pos' &&
          prop.ref.format == mpv_format.MPV_FORMAT_DOUBLE) {
        position.value = prop.ref.data.cast<Double>().value ~/ 1;
      } else if (propName == 'video-out-params' &&
          prop.ref.format == mpv_format.MPV_FORMAT_NODE) {
        final node = prop.ref.data.cast<mpv_node>().ref;
        final data = <String, dynamic>{};
        for (int i = 0; i < node.u.list.ref.num; i++) {
          final key = node.u.list.ref.keys[i].cast<Utf8>().toDartString();
          final value = node.u.list.ref.values[i];
          switch (value.format) {
            case mpv_format.MPV_FORMAT_INT64:
              data[key] = value.u.int64;
              break;
            case mpv_format.MPV_FORMAT_DOUBLE:
              data[key] = value.u.double_;
              break;
            case mpv_format.MPV_FORMAT_STRING:
              data[key] = value.u.string.cast<Utf8>().toDartString();
              break;
            default:
              break;
          }
        }

        final params = VideoParams(
          pixelformat: data['pixelformat'],
          hwPixelformat: data['hw-pixelformat'],
          w: data['w'],
          h: data['h'],
          dw: data['dw'],
          dh: data['dh'],
          aspect: data['aspect'],
          par: data['par'],
          colormatrix: data['colormatrix'],
          colorlevels: data['colorlevels'],
          primaries: data['primaries'],
          gamma: data['gamma'],
          sigPeak: data['sig-peak'],
          light: data['light'],
          chromaLocation: data['chroma-location'],
          rotate: data['rotate'],
          stereoIn: data['stereo-in'],
          averageBpp: data['average-bpp'],
          alpha: data['alpha'],
        );

        videoParams.value = params;

        final dw = params.dw;
        final dh = params.dh;
        final rotate = params.rotate ?? 0;
        if (dw > 0 && dh > 0) {
          final int width;
          final int height;
          if (rotate == 0 || rotate == 180) {
            width = dw;
            height = dh;
          } else {
            // width & height are swapped for 90 or 270 degrees rotation.
            width = dh;
            height = dw;
          }
          setOutputSize(width: width, height: height);
        }
      } else if (propName == 'audio-params' &&
          prop.ref.format == mpv_format.MPV_FORMAT_NODE) {
        final data = prop.ref.data.cast<mpv_node>();
        final list = data.ref.u.list.ref;
        final params = <String, dynamic>{};
        for (int i = 0; i < list.num; i++) {
          final key = list.keys[i].cast<Utf8>().toDartString();

          switch (key) {
            case 'format':
              {
                params[key] =
                    list.values[i].u.string.cast<Utf8>().toDartString();
                break;
              }
            case 'samplerate':
              {
                params[key] = list.values[i].u.int64;
                break;
              }
            case 'channels':
              {
                params[key] =
                    list.values[i].u.string.cast<Utf8>().toDartString();
                break;
              }
            case 'channel-count':
              {
                params[key] = list.values[i].u.int64;
                break;
              }
            case 'hr-channels':
              {
                params[key] =
                    list.values[i].u.string.cast<Utf8>().toDartString();
                break;
              }
            default:
              {
                break;
              }
          }
        }
        audioParams.value = AudioParams(
          format: params['format'],
          sampleRate: params['samplerate'],
          channels: params['channels'],
          channelCount: params['channel-count'],
          hrChannels: params['hr-channels'],
        );
      }
      if (_observedProperties.contains(propName)) {
        propertyChangedCallback?.call(propName, prop.ref.format);
      }
    }
  }
}
