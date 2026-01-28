import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;
import 'package:open_file/open_file.dart';
import '../../../constants/api_constants.dart';
import 'apply_models.dart';

// 格式化时间
String formatTime(String timeStr) {
  if (timeStr.isEmpty || timeStr == 'null') return '未知时间';

  try {
    DateTime dateTime;

    // 处理ISO格式（含T/Z）
    if (timeStr.contains('T') || timeStr.endsWith('Z')) {
      dateTime = DateTime.parse(timeStr);
      // 转换为北京时间
      dateTime = dateTime.add(const Duration(hours: 8));
    }
    // 处理其他格式
    else {
      dateTime = DateTime.parse(timeStr);
    }

    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  } catch (e) {
    dev.log('时间格式化失败: $e, time: $timeStr');
    return timeStr.isNotEmpty ? timeStr : '未知时间';
  }
}

// 格式化文件大小
String formatFileSize(int? size) {
  if (size == null || size <= 0) {
    return '0 B';
  }

  if (size < 1024) {
    return '$size B';
  } else if (size < 1024 * 1024) {
    return '${(size / 1024).toStringAsFixed(1)} KB';
  } else if (size < 1024 * 1024 * 1024) {
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  } else {
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// 打开文件（修复后的核心方法）
Future<void> openFile(ApplyFile file, BuildContext context, {Function(String)? onError}) async {
  try {
    // 拼接完整URL并编码
    String fullFileUrl = file.fileUrl.startsWith('http')
        ? file.fileUrl
        : Uri.encodeFull('$baseUrl${file.fileUrl}');

    dev.log('文件预览地址: $fullFileUrl');

    // 图片文件特殊处理 - 弹窗预览
    if (file.fileType.startsWith('image/') ||
        file.fileName.toLowerCase().contains('.png') ||
        file.fileName.toLowerCase().contains('.jpg') ||
        file.fileName.toLowerCase().contains('.jpeg') ||
        file.fileName.toLowerCase().contains('.gif')) {

      await showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 可缩放的图片预览
              InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.5,
                maxScale: 3.0,
                child: Image.network(
                  fullFileUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 300,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              ),
              // 文件信息和关闭按钮
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.fileName,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatFileSize(file.fileSize)} | ${formatTime(file.uploadTime ?? '')}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    // PDF和其他文件类型
    else {
      final result = await OpenFile.open(fullFileUrl);
      if (result.type != ResultType.done) {
        String errorMsg = '无法打开文件: ${result.message}';
        dev.log(errorMsg);
        if (onError != null) {
          onError(errorMsg);
        }
        // 备用方案：复制链接到剪贴板
        await Clipboard.setData(ClipboardData(text: fullFileUrl));
        if (onError != null) {
          onError('无法打开文件，已将文件链接复制到剪贴板');
        }
      }
    }
  } catch (e) {
    String errorMsg = '打开文件失败: $e';
    dev.log(errorMsg);
    if (onError != null) {
      onError(errorMsg);
    }
  }
}

// 构建文件列表项
Widget buildFileItem(ApplyFile file, BuildContext context, {Function(String)? onError}) {
  // 文件图标和颜色
  IconData fileIcon = Icons.insert_drive_file;
  Color iconColor = Colors.grey;

  if (file.fileType.startsWith('image/') ||
      file.fileName.toLowerCase().contains('.png') ||
      file.fileName.toLowerCase().contains('.jpg') ||
      file.fileName.toLowerCase().contains('.jpeg')) {
    fileIcon = Icons.image;
    iconColor = Colors.pinkAccent;
  } else if (file.fileType.contains('pdf') || file.fileName.toLowerCase().contains('.pdf')) {
    fileIcon = Icons.picture_as_pdf;
    iconColor = Colors.redAccent;
  } else if (file.fileType.contains('excel') ||
      file.fileName.toLowerCase().endsWith('.xlsx') ||
      file.fileName.toLowerCase().endsWith('.xls')) {
    fileIcon = Icons.table_chart;
    iconColor = Colors.greenAccent;
  } else if (file.fileType.contains('word') ||
      file.fileName.toLowerCase().endsWith('.docx') ||
      file.fileName.toLowerCase().endsWith('.doc')) {
    fileIcon = Icons.description;
    iconColor = Colors.blueAccent;
  } else if (file.fileType.contains('zip') ||
      file.fileName.toLowerCase().endsWith('.zip') ||
      file.fileName.toLowerCase().endsWith('.rar')) {
    fileIcon = Icons.archive;
    iconColor = Colors.orangeAccent;
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.grey.withOpacity(0.05),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.grey.withOpacity(0.1)),
    ),
    child: InkWell(
      onTap: () => openFile(file, context, onError: onError),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          // 图片预览或文件图标
          file.fileType.startsWith('image/')
              ? ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              file.fileUrl.startsWith('http') ? file.fileUrl : Uri.encodeFull('$baseUrl${file.fileUrl}'),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.broken_image,
                color: iconColor,
                size: 48,
              ),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    color: iconColor,
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
            ),
          )
              : Icon(
            fileIcon,
            color: iconColor,
            size: 48,
          ),
          const SizedBox(width: 12),
          // 文件信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      formatTime(file.uploadTime ?? ''),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF86909C)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatFileSize(file.fileSize),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF86909C)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Color(0xFF86909C),
          ),
        ],
      ),
    ),
  );
}

// 构建文件列表组件
Widget buildFileList(List<ApplyFile> files, String title, BuildContext context, {String? userId, Function(String)? onError}) {
  if (files.isEmpty) {
    return const SizedBox.shrink();
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0088FF),
        ),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: files.map((file) => buildFileItem(file, context, onError: onError)).toList(),
        ),
      ),
    ],
  );
}