# libmpv_dart


libmpv_dart is a Dart binding for [libmpv](https://github.com/mpv-player/mpv/tree/master/include/mpv),aiming to provide Dart users with an efficient and convenient way to use libmpv.

a package that provides ability to access libmpv feature in dart application.

| Platform | libmpv API | Video Render |
| -------- | ---------- | ------------ |
| Windows  | ✓          | ✓            |
| Linux    | ✓          |              |
| macOS    | ✓          |              |
| android  | ✓          |              |

## Setup

First,add libmpv_dart to your pubspec.yaml:

```
flutter pub add libmpv_dart
```

For windows/android users,run following command in your terminal:

```shell
dart run libmpv_dart:setup --platform windows
dart run libmpv_dart:setup --platform android
```

For linux users,all you need to do is install libmpv.

```shell
sudo apt install libmpv-dart
```

## How to use?

Generate a player instance(corresponding to mpv_handle)

```dart
// initial options for players
_player = Player(
  {
    'config': 'yes',
    'input-default-bindings': 'yes',
  },
  videoOutput: true,
);
_player.setPropertyString('keep-open', 'yes');
```

then you can execute some command,for example.load a file:

```dart
player.command(["loadfile",inputPath]);
```

After all the jobs are done,destory the player to free memory:

```dart
player.destroy();
```

or you can wait for a mpv event:

```dart
while (true) {
  Pointer<mpv_event> event = player.waitEvent(0);
  if (event.ref.event_id == mpv_event_id.MPV_EVENT_SHUTDOWN) {
    break;
  } else if (event.ref.event_id == mpv_event_id.MPV_EVENT_END_FILE) {
    break;
  }
  //wait until event happen.
}
```

## credits

This project is based on open-source projects. Some of the source code has been adapted or reused from the following project:

[**media-kit**](https://github.com/media-kit/media-kit) [LICENSE](https://github.com/media-kit/media-kit/blob/4d8c634c28d439384aab40b9d2edff83077f37c9/LICENSE)
