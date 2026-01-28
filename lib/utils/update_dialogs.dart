import 'package:flutter/material.dart';
import 'package:workflow/utils/update_manager.dart';
import 'dart:io';

// 更新弹窗工具类（仅处理 UI 展示，无业务逻辑）
class UpdateDialogs {
  // 1. 展示加载弹窗（检查更新/下载中）
  static void showLoadingDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF0088FF)),
            SizedBox(width: 16),
            Text(title),
          ],
        ),
      ),
    );
  }

  // 2. 展示通用更新提示弹窗（失败、最新、有更新）
  static void showUpdateTipDialog(
      BuildContext context, {
        required String title,
        required String content,
        required bool showDownloadButton,
        AppVersionModel? latestVersion,
        VoidCallback? onDownloadTap,
      }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(color: Color(0xFF333333), fontSize: 16),
        ),
        content: Text(
          content,
          style: TextStyle(color: Color(0xFF666666), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFF333333),
            ),
            child: Text("取消"),
          ),
          // 优化：增加多层校验，确保只有需要更新且回调不为空时，才展示下载按钮
          if (showDownloadButton && latestVersion != null && onDownloadTap != null)
            ElevatedButton(
              onPressed: onDownloadTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0088FF),
                foregroundColor: Colors.white,
              ),
              child: Text("立即下载更新"),
            ),
        ],
      ),
    );
  }

  // 3. 展示下载完成弹窗（提示是否立即安装）
  static void showDownloadCompleteDialog(
      BuildContext context,
      File installerFile,
      VoidCallback? onInstallTap,
      ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "下载完成",
          style: TextStyle(color: Color(0xFF333333), fontSize: 16),
        ),
        content: Text(
          "安装包已保存至：\n${installerFile.path}\n\n是否立即安装更新？",
          style: TextStyle(color: Color(0xFF666666), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFF333333),
            ),
            child: Text("稍后安装"),
          ),
          if (onInstallTap != null)
            ElevatedButton(
              onPressed: onInstallTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0088FF),
                foregroundColor: Colors.white,
              ),
              child: Text("立即安装"),
            ),
        ],
      ),
    );
  }
}