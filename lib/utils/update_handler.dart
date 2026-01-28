import 'package:flutter/material.dart';
import 'package:workflow/utils/update_dialogs.dart';
import 'package:workflow/utils/update_manager.dart';

class UpdateHandler {
  // 新增可选参数 isSilent，默认值为 false（手动触发场景，不静默）
  static Future<void> handleCheckUpdate(BuildContext context, {bool isSilent = false}) async {
    // 1. 展示「正在检查更新」弹窗
    UpdateDialogs.showLoadingDialog(context, "正在检查更新...");

    // 2. 获取最新版本信息
    final latestVersion = await UpdateManager.getLatestVersion();

    // 关闭加载弹窗
    Navigator.pop(context);

    // 3. 处理异常情况（未获取到版本信息）
    if (latestVersion == null) {
      UpdateDialogs.showUpdateTipDialog(
        context,
        title: "检查更新失败",
        content: "无法连接到更新服务器，请稍后再试。",
        showDownloadButton: false,
      );
      return;
    }

    // 关键：在使用前，正确定义 needToUpdate 局部变量
    final bool needToUpdate = UpdateManager.needUpdate(latestVersion);

    // 4. 若是最新版本，根据 isSilent 参数判断是否展示弹窗
    if (!needToUpdate) {
      if (!isSilent) {
        UpdateDialogs.showUpdateTipDialog(
          context,
          title: "已是最新版本",
          // 修复：使用 VersionConstants 中的静态常量
          content: "当前版本：${VersionConstants.localVersionName}\n最新版本：${latestVersion.versionName}",
          showDownloadButton: false,
        );
      }
      return;
    }

    // 5. 有更新时，正常展示带下载按钮的弹窗
    UpdateDialogs.showUpdateTipDialog(
      context,
      title: "发现新版本 ${latestVersion.versionName}",
      content: """
当前版本：${VersionConstants.localVersionName}
最新版本：${latestVersion.versionName}
安装包大小：${latestVersion.packageSize}

更新日志：
${latestVersion.changelog}
""",
      showDownloadButton: needToUpdate,
      latestVersion: latestVersion,
      onDownloadTap: () {
        Navigator.pop(context);
        _handleDownloadAndInstall(context, latestVersion);
      },
    );
  }

  // 内部方法：处理下载和安装
  static Future<void> _handleDownloadAndInstall(
      BuildContext context,
      AppVersionModel latestVersion,
      ) async {
    UpdateDialogs.showLoadingDialog(context, "正在下载安装包...");
    final installerFile = await UpdateManager.downloadPackage(latestVersion.packageUrl);
    Navigator.pop(context);

    if (installerFile == null) {
      UpdateDialogs.showUpdateTipDialog(
        context,
        title: "下载失败",
        content: "安装包下载失败，请检查网络连接后重试。",
        showDownloadButton: false,
      );
      return;
    }

    // 跳过弹窗，直接执行安装
    Navigator.pop(context);
    UpdateManager.runInstaller(installerFile);
  }
}