import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell.dart';
import 'package:workflow/constants/api_constants.dart';

// 本地版本信息（改为静态常量，供外部访问）
class VersionConstants {
  static const int localVersionCode = 8;
  static const String localVersionName = "1.0.7";
}

// 版本信息模型（存储服务端返回的最新版本数据）
class AppVersionModel {
  final int versionCode;
  final String versionName;
  final String changelog;
  final String packageUrl;
  final String packageSize;

  AppVersionModel({
    required this.versionCode,
    required this.versionName,
    required this.changelog,
    required this.packageUrl,
    required this.packageSize,
  });

  // 从 JSON 解析模型（适配 Node.js 接口返回格式）
  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    return AppVersionModel(
      versionCode: json['versionCode'] as int,
      versionName: json['versionName'] as String,
      changelog: json['changelog'] as String,
      packageUrl: json['packageUrl'] as String,
      packageSize: json['packageSize'] as String,
    );
  }
}

// 更新管理核心工具类（仅处理业务逻辑，无 UI 代码）
class UpdateManager {
  // 1. 获取服务端最新版本信息
  static Future<AppVersionModel?> getLatestVersion() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/version/latest'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);
        if (result['code'] == 0) {
          return AppVersionModel.fromJson(result['data']);
        } else {
          print('获取版本信息失败：${result['message']}');
          return null;
        }
      } else {
        print('接口请求失败，状态码：${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('获取版本信息异常：$e');
      return null;
    }
  }

  // 2. 对比版本（判断是否需要更新）
  static bool needUpdate(AppVersionModel latestVersion) {
    return latestVersion.versionCode > VersionConstants.localVersionCode;
  }

  // 3. 下载安装包（保存到 Windows 「我的文档」目录）
  static Future<File?> downloadPackage(String packageUrl) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final savePath = directory.path;
      final fileName = packageUrl.split('/').last;
      final localFile = File('$savePath/$fileName');

      final response = await http.get(Uri.parse(packageUrl));
      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        print('安装包下载完成，保存路径：${localFile.path}');
        return localFile;
      } else {
        print('安装包下载失败，状态码：${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('安装包下载异常：$e');
      return null;
    }
  }

  // 4. 执行安装包（完成 Windows 应用更新，新增自动启动逻辑）
  static Future<bool> runInstaller(File installerFile) async {
    try {
      if (!await installerFile.exists()) {
        print('安装包不存在：${installerFile.path}');
        return false;
      }

      // 只定义一次 installConfig 变量
      final installConfig = await getInstallConfig();
      // 关键修改：移除 /NORESTART（允许安装包重启应用）
      String installArgs = '/VERYSILENT /SUPPRESSMSGBOXES /RUNASADMIN /CLOSEAPPLICATIONS';

      // 如果有历史路径，指定安装路径
      if (installConfig != null && installConfig['installPath'] != null) {
        installArgs += ' /DIR="${installConfig['installPath']}"';
      }

      final shell = Shell();
      // 同步执行安装包，确保安装完成后再处理后续逻辑
      await shell.run('"${installerFile.path}" $installArgs');
      print('安装包执行完成，准备启动新应用');

      // 兜底：复用已定义的 installConfig，手动启动新应用
      if (installConfig != null && installConfig['installPath'] != null) {
        final newAppPath = '${installConfig['installPath']}/workflow.exe';
        final newAppFile = File(newAppPath);
        if (await newAppFile.exists()) {
          await shell.run('"$newAppPath"'); // 手动启动新应用
          print('手动启动新应用成功：$newAppPath');
        } else {
          print('新应用文件不存在：$newAppPath');
        }
      } else {
        print('无历史安装路径，无法手动启动新应用');
      }

      // 延迟延长到5秒，给新应用足够启动时间
      Future.delayed(const Duration(seconds: 5), () {
        exit(0); // 关闭旧应用
      });

      return true;
    } catch (e) {
      print('启动安装包异常：$e');
      return false;
    }
  }

  // 保存安装路径到本地配置文件
  static Future<void> saveInstallPath(String installPath) async {
    final directory = await getApplicationDocumentsDirectory();
    final configFile = File('${directory.path}/install_config.json');
    // 替换为你的实际应用 exe 名称
    await configFile.writeAsString(json.encode({
      'installPath': installPath,
      'appExeName': 'workflow.exe',
    }));
  }

  // 读取安装配置（包含路径和应用名）
  static Future<Map<String, String>?> getInstallConfig() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final configFile = File('${directory.path}/install_config.json');
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final config = json.decode(content);
        return {
          'installPath': config['installPath'] as String,
          'appExeName': config['appExeName'] as String,
        };
      }
    } catch (e) {
      print('读取安装配置异常：$e');
    }
    return null;
  }

  // 新增：兼容方法 getLastInstallPath()，避免调用处报错
  static Future<String?> getLastInstallPath() async {
    final config = await getInstallConfig();
    return config?['installPath'];
  }
}