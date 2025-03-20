// ignore_for_file: avoid_print

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as path;

Future<void> setup4Linux() async {}

Future<void> setup4Windows({String mode = "debug"}) async {
  Uri url = Uri.parse("");
  String filename = "";

  url = Uri.parse(
    'https://github.com/Playboy-Player/mpv-winbuild/releases/download/2025-02-26-5ae0e0f/mpv-dev-x86_64-20250226-git-5ae0e0f.zip',
  );
  filename = 'mpv-dev-lib.zip';

  var packageConfig = await findPackageConfig(Directory.current);
  if (packageConfig == null) {
    print("Package config not found.");
    return;
  }
  // 查找特定插件的包信息
  var pluginPackage =
      packageConfig.packages.firstWhere((pkg) => pkg.name == 'libmpv_dart');
  // 使用这个信息得到插件根目录
  var pluginRootPath =
      pluginPackage.packageUriRoot.toFilePath(windows: Platform.isWindows);
  // 新的目录路径
  var newFolder = 'src/dynamicLib/windows';
  var newPath = path.join(path.dirname(pluginRootPath), newFolder);

  // 下载文件
  var response = await http.get(url);
  if (response.statusCode == 200) {
    var file = File(filename);
    await file.writeAsBytes(response.bodyBytes);
    print('File downloaded and saved as $filename');

    // 读取ZIP文件
    var bytes = await file.readAsBytes();
    var archive = ZipDecoder().decodeBytes(bytes);

    // 创建新的目录来解压缩文件
    Directory(newPath).createSync(recursive: true);

    // 从压缩包中提取文件
    for (var file in archive) {
      var fileName = file.name;

      // 如果是根目录下的文件夹，则跳过不解压缩
      if (file.isFile || path.split(fileName).length != 1) {
        var data = file.content as List<int>;
        var outputPath = path.join(newPath, fileName);

        // 确保父目录存在
        Directory(path.dirname(outputPath)).createSync(recursive: true);

        if (file.isFile) {
          File(outputPath).writeAsBytesSync(data);
        } else {
          // 如果项是文件夹，则创建文件夹
          Directory(outputPath).createSync(recursive: true);
        }
        print('Extracted: $outputPath');
      }
    }
    print('Files extracted to $newFolder');

    // 删除下载的ZIP文件
    await file.delete();
    print('ZIP file deleted');
  } else {
    print('Failed to download file: ${response.statusCode}');
  }
}

Future<void> setup4Android() async {
  // 文件的URL
  var url = Uri.parse(
    'https://github.com/Playboy-Player/libmpv_android_build/archive/refs/heads/main.zip',
  );
  print("Downloading prebuilt library.");
  var response = await http.get(url);
  if (response.statusCode == 200) {
    var archive = ZipDecoder().decodeBytes(response.bodyBytes);

    var packageConfig = await findPackageConfig(Directory.current);
    if (packageConfig == null) {
      print("Package config not found.");
      return;
    }

    // 查找特定插件的包信息
    var pluginPackage =
        packageConfig.packages.firstWhere((pkg) => pkg.name == 'libmpv_dart');
    // 使用这个信息得到插件根目录
    var pluginRootPath =
        pluginPackage.packageUriRoot.toFilePath(windows: Platform.isWindows);

    // 循环每个文件
    for (var file in archive) {
      // 获得文件路径的所有组成部分
      var filePathParts = path.split(file.name);

      // 只保留从 "jni" 开始的路径部分
      int jniIndex = filePathParts.indexOf("jni");
      if (jniIndex == -1) {
        continue; // 跳过不包含 "jni" 的文件
      }
      var newFilePathParts = filePathParts.sublist(jniIndex);
      var newFilePath = path.joinAll(newFilePathParts);

      // 只处理路径中包含 "jni" 的文件或文件夹
      if (file.name.contains("jni")) {
        if (file.isFile) {
          final data = file.content as List<int>;
          final outputPath = path.join(
              "$pluginRootPath/../src/dynamicLib/android", newFilePath);
          // 确保父目录存在
          final directory = Directory(path.dirname(outputPath));
          if (!directory.existsSync()) {
            directory.createSync(recursive: true);
          }
          File(outputPath).writeAsBytesSync(data);
        } else {
          Directory(
            path.join("$pluginRootPath/../src/dynamicLib/android", newFilePath),
          ).createSync(recursive: true);
        }
      }
    }
    print('Extraction done.');
  } else {
    print('Failed to download file: ${response.statusCode}');
  }
}

Future<void> setup4MacOS() async {}

void main(List<String> arguments) async {
  print('Setting up libmpv_dart...');
  String command = arguments[0];
  if (command == '--platform') {
    if (arguments[1] == 'linux') {
      await setup4Linux();
    } else if (arguments[1] == 'windows') {
      await setup4Windows();
    } else if (arguments[1] == 'android') {
      await setup4Android();
    } else if (arguments[1] == 'macos') {
      await setup4MacOS();
    } else {
      print('Platform is not supported!');
    }
  }
}
