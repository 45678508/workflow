import 'package:flutter/material.dart';
import 'status_util.dart';
import 'dart:developer' as dev;

// 文件数据模型
class ApplyFile {
  final String fileName;
  final String fileType;
  final String fileUrl;
  final String uploadTime;
  final int? fileSize;

  ApplyFile({
    required this.fileName,
    required this.fileType,
    required this.fileUrl,
    required this.uploadTime,
    this.fileSize,
  });

  // 从JSON解析
  factory ApplyFile.fromJson(Map<String, dynamic> json) {
    return ApplyFile(
      fileName: json['fileName'] ?? '',
      fileType: json['fileType'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
      uploadTime: json['uploadTime'] ?? '',
      fileSize: json['fileSize'] as int?,
    );
  }

  // 格式化文件大小显示
  String get formattedFileSize {
    if (fileSize == null || fileSize == 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    double size = fileSize!.toDouble();

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }
}

// 申请单核心模型
class ApplyTodoModel {
  final String id;
  final String applicant;
  final String customer;
  final String business;
  final String leaderName;
  final List<ResponsiblePerson> responsibles;
  final String overallStatus;
  final DateTime applyTime;
  final DateTime expectedCompletionTime;
  final List<ApplyFile> applyFiles;
  final String customContent;

  ApplyTodoModel({
    required this.id,
    required this.applicant,
    required this.customer,
    required this.business,
    required this.leaderName,
    required this.responsibles,
    required this.overallStatus,
    required this.applyTime,
    required this.expectedCompletionTime,
    this.applyFiles = const [],
    required this.customContent
  });

  String get overallStatusChinese {
    return StatusUtil.getStatusChinese(overallStatus);
  }

  Color get overallStatusColor {
    return StatusUtil.getStatusColor(overallStatus);
  }

  // 从JSON解析
  factory ApplyTodoModel.fromJson(Map<String, dynamic> json) {
    // 安全解析日期
    DateTime parseSafeDate(String? key) {
      try {
        final String? timeStr = json[key];
        if (timeStr == null || timeStr.isEmpty) return DateTime.now();
        return DateTime.parse(timeStr);
      } catch (e) {
        dev.log('日期解析失败：$e', name: 'ApplyTodoModel.parseSafeDate');
        return DateTime.now();
      }
    }

    // 解析多负责人列表
    List<ResponsiblePerson> parseResponsibles() {
      List<ResponsiblePerson> list = [];
      if (json['responsibles'] is List) {
        for (var item in json['responsibles']) {
          list.add(ResponsiblePerson.fromJson(item));
        }
      }
      return list;
    }

    // 解析开案文件列表
    List<ApplyFile> parseApplyFiles() {
      List<ApplyFile> list = [];
      if (json['applyFiles'] is List) {
        for (var item in json['applyFiles']) {
          list.add(ApplyFile.fromJson(item));
        }
      }
      return list;
    }

    return ApplyTodoModel(
      id: json['_id'] ?? '',
      applicant: json['applicant'] ?? '',
      customer: json['customer'] ?? '',
      business: json['business'] ?? '',
      leaderName: json['leaderName'] ?? '',
      responsibles: parseResponsibles(),
      overallStatus: json['overallStatus'] ?? 'in_progress',
      applyTime: parseSafeDate('applyTime'),
      expectedCompletionTime: parseSafeDate('expectedCompletionTime'),
      applyFiles: parseApplyFiles(),
      // 修复：添加必填的 customContent 参数
      customContent: json['customContent'] ?? '',
    );
  }
}

// 负责人模型
class ResponsiblePerson {
  final String role;
  final String userId;
  final String username;
  final String personalStatus;
  final String? taskContent;
  final String? leaderContent;
  final String? startTime;
  final String? completeTime;
  final List<ApplyFile> files;
  final List<ApplyFile> leaderfiles;

  ResponsiblePerson({
    required this.role,
    required this.userId,
    required this.username,
    required this.personalStatus,
    this.taskContent,
    this.leaderContent,
    this.startTime,
    this.completeTime,
    this.files = const [],
    this.leaderfiles = const [],
  });

  // 从JSON解析
  factory ResponsiblePerson.fromJson(Map<String, dynamic> json) {
    // 解析负责人文件列表
    List<ApplyFile> parseFiles() {
      List<ApplyFile> list = [];
      if (json['files'] is List) {
        for (var item in json['files']) {
          list.add(ApplyFile.fromJson(item));
        }
      }
      return list;
    }
    // 新增：解析组长文件列表
    List<ApplyFile> parseLeaderFiles() {
      List<ApplyFile> list = [];
      if (json['leaderfiles'] is List) {
        for (var item in json['leaderfiles']) {
          list.add(ApplyFile.fromJson(item));
        }
      }
      return list;
    }

    return ResponsiblePerson(
      role: json['role'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      personalStatus: json['personalStatus'] ?? 'not_started',
      taskContent: json['taskContent'],
      leaderContent: json['leaderContent'],
      startTime: json['startTime'],
      completeTime: json['completeTime'],
      files: parseFiles(),
      leaderfiles: parseLeaderFiles(),
    );
  }
}

// 详情页申请单模型
class DetailApplyTodoModel {
  final String id;
  final String customer;
  final String business;
  final String applicant;
  final DateTime applyTime;
  final String leaderName;
  final DateTime expectedCompletionTime;
  final List<DetailTaskPerson> responsibles;
  final String overallStatus;
  final List<ApplyFile> applyFiles;
  // 修复：添加 customContent 字段
  final String customContent;

  DetailApplyTodoModel({
    required this.id,
    required this.customer,
    required this.business,
    required this.applicant,
    required this.applyTime,
    required this.leaderName,
    required this.expectedCompletionTime,
    required this.responsibles,
    this.overallStatus = 'not_started',
    this.applyFiles = const [],
    // 修复：添加 customContent 参数（设置默认值避免必填）
    this.customContent = '',
  });

  String get overallStatusChinese => StatusUtil.getStatusChinese(overallStatus);
  Color get overallStatusColor => StatusUtil.getStatusColor(overallStatus);
}

// 详情页负责人模型
class DetailTaskPerson {
  final String role;
  final String userId;
  final String username;
  final String personalStatus;
  final String? taskContent;
  final String? leaderContent;
  final String? startTime;
  final String? completeTime;
  final List<ApplyFile> files;
  final List<ApplyFile> leaderfiles;

  DetailTaskPerson({
    required this.role,
    required this.userId,
    required this.username,
    required this.personalStatus,
    this.taskContent,
    this.leaderContent,
    this.startTime,
    this.completeTime,
    this.files = const [],
    this.leaderfiles = const [],
  });

  // 状态颜色
  Color get personalStatusColor {
    return StatusUtil.getStatusColor(personalStatus);
  }

  // 状态中文名称
  String get personalStatusChinese {
    return StatusUtil.getStatusChinese(personalStatus);
  }
}

// 详情页详细负责人模型
class DetailDetailedTaskPerson {
  final String role;
  final String userId;
  final String username;
  final String personalStatus;
  final String taskContent;
  final String? leaderContent;
  final String? startTime;
  final String? completeTime;
  final List<ApplyFile> files;
  final List<ApplyFile> leaderfiles;

  DetailDetailedTaskPerson({
    required this.role,
    required this.userId,
    required this.username,
    required this.personalStatus,
    this.taskContent = '暂无任务内容',
    this.leaderContent,
    this.startTime,
    this.completeTime,
    this.files = const [],
    this.leaderfiles = const [],
  });

  // 从JSON解析
  factory DetailDetailedTaskPerson.fromJson(Map<String, dynamic> json) {
    // 解析负责人文件列表
    List<ApplyFile> parseFiles() {
      List<ApplyFile> list = [];
      if (json['files'] is List) {
        for (var item in json['files']) {
          list.add(ApplyFile.fromJson(item));
        }
      }
      return list;
    }

    // 新增：解析组长文件列表
    List<ApplyFile> parseLeaderFiles() {
      List<ApplyFile> list = [];
      if (json['leaderfiles'] is List) {
        for (var item in json['leaderfiles']) {
          list.add(ApplyFile.fromJson(item));
        }
      }
      return list;
    }

    final String processedTaskContent = (json['taskContent'] ?? '').toString().trim().isEmpty
        ? '暂无任务描述'
        : json['taskContent'].toString().trim();

    return DetailDetailedTaskPerson(
      role: json['role'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      personalStatus: json['personalStatus'] ?? 'not_started',
      taskContent: processedTaskContent,
      leaderContent: json['leaderContent'] ?? '暂无',
      startTime: json['startTime'],
      completeTime: json['completeTime'],
      files: parseFiles(),
      leaderfiles: parseLeaderFiles(),
    );
  }

  // 角色中文名称
  String get roleChineseName {
    switch (role) {
      case 'software':
        return '软件';
      case 'hardware':
        return '硬件';
      case 'test':
        return '测试';
      default:
        return '未知';
    }
  }

  // 状态中文名称
  String get personalStatusChineseName {
    return StatusUtil.getStatusChinese(personalStatus);
  }

  // 状态对应颜色
  Color get statusColor {
    return StatusUtil.getStatusColor(personalStatus);
  }

  // 验证是否为当前登录用户
  bool isCurrentUser(String currentUserId) => userId == currentUserId;
}