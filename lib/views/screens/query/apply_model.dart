import 'package:flutter/material.dart';
import 'dart:developer' as dev;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';

// 初始化时区（全局）
void initTimeZone() {
  initializeDateFormatting('zh_CN', null);
}

// 单个负责人详细数据模型（强化逾期状态显示）
class ResponsibleDetailModel {
  final String role;
  final String userId;
  final String username;
  // 🔴 修改：移除 final，使其可修改
  String personalStatus;
  String taskContent;
  final String leaderContent;
  final String? startTime;
  // 🔴 修改：移除 final，使其可修改
  String? completeTime;
  // 新增：文件列表字段
  final List<FileModel> leaderfiles;
  // 🔴 修改：移除 final，使其可修改
  List<FileModel> files;
  // 🔴 修改：移除 final，使其可修改
  TestFeedbackModel? testFeedback;
  // 🔴 修改：移除 final，使其可修改
  List<RejectRecordModel> rejectRecords;

  ResponsibleDetailModel({
    required this.role,
    required this.userId,
    required this.username,
    required this.personalStatus,
    required this.taskContent,
    this.leaderContent = '',
    this.startTime,
    this.completeTime,
    // 新增：默认空列表
    this.files = const [],
    this.leaderfiles = const [],
    this.testFeedback,
    this.rejectRecords = const [],
  });

  factory ResponsibleDetailModel.fromJson(Map<String, dynamic> json) {
    // 解析文件列表
    List<FileModel> files = [];
    if (json['files'] != null && json['files'] is List) {
      files = (json['files'] as List)
          .map((fileJson) => FileModel.fromJson(fileJson))
          .toList();
    }
    // 解析组长上传的文件列表
    List<FileModel> leaderfiles = [];
    if (json['leaderfiles'] != null && json['leaderfiles'] is List) {
      leaderfiles = (json['leaderfiles'] as List)
          .map((fileJson) => FileModel.fromJson(fileJson))
          .toList();
    }

    return ResponsibleDetailModel(
      role: json['role'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '未知负责人',
      // 强制兜底：确保状态值有效
      personalStatus: json['personalStatus'] ?? 'not_started',
      taskContent: json['taskContent'] ?? '暂无',
      leaderContent: json['leaderContent'] ?? '暂无',
      startTime: json['startTime'] != null ? formatToBeijingTime(json['startTime']) : null,
      completeTime: json['completeTime'] != null ? formatToBeijingTime(json['completeTime']) : null,
      files: files,
      leaderfiles: leaderfiles,
      testFeedback: json['testFeedback'] != null
          ? TestFeedbackModel.fromJson(json['testFeedback'])
          : null,
      rejectRecords: (json['rejectRecords'] as List?)
          ?.map((item) => RejectRecordModel.fromJson(item))
          .toList() ?? [],
    );
  }

  String get roleCn {
    switch (role) {
      case 'hardware':
        return '硬件';
      case 'software':
        return '软件';
      case 'test':
        return '测试';
      default:
        return '未知';
    }
  }

  String get personalStatusCn {
    switch (personalStatus) {
      case 'not_started':
        return '未开始';
      case 'in_progress':
        return '进行中';
      case 'overdue':
        return '逾期';
      case 'completed':
        return '已完成';
      case 'paused':
        return '暂停';
      default:
        return '未知状态';
    }
  }

  Color get statusColor {
    switch (personalStatus) {
      case 'not_started':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'overdue':
        return Colors.redAccent;
      case 'completed':
        return Colors.green;
      case 'paused':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  PdfColor get pdfStatusColor {
    switch (personalStatus) {
      case 'not_started':
        return PdfColors.grey;
      case 'in_progress':
        return PdfColors.blue;
      case 'overdue':
        return PdfColors.red;
      case 'completed':
        return PdfColors.green;
      case 'paused':
        return PdfColors.yellow;
      default:
        return PdfColors.grey;
    }
  }
}

// 测试反馈模型
class TestFeedbackModel {
  final String content;
  final String creatorId;
  final String creatorName;
  final String createTime;
  final bool isEditable;

  TestFeedbackModel({
    required this.content,
    required this.creatorId,
    required this.creatorName,
    required this.createTime,
    required this.isEditable,
  });

  factory TestFeedbackModel.fromJson(Map<String, dynamic> json) {
    return TestFeedbackModel(
      content: json['content'] ?? '',
      creatorId: json['creatorId'] ?? '',
      creatorName: json['creatorName'] ?? '',
      createTime: json['createTime'] != null ? formatToBeijingTime(json['createTime']) : '',
      isEditable: json['isEditable'] ?? false,
    );
  }
}

// 打回记录模型
class RejectRecordModel {
  final String rejectTime;
  final String rejectorName;
  final String reason;

  RejectRecordModel({
    required this.rejectTime,
    required this.rejectorName,
    required this.reason,
  });

  factory RejectRecordModel.fromJson(Map<String, dynamic> json) {
    return RejectRecordModel(
      rejectTime: json['rejectTime'] != null ? formatToBeijingTime(json['rejectTime']) : '',
      rejectorName: json['rejectorName'] ?? '',
      reason: json['reason'] ?? '',
    );
  }
}

// 申请数据模型（修复逾期天数计算+强化状态判断）
class ApplyModel {
  final String id;
  final String userId;
  final String userName;
  final String customer;
  final String business;
  final String expectedCompletionTime;
  final String applyTime;
  final String applicant;
  final List<String> hardwareHandlers;
  final List<String> softwareHandlers;
  final List<String> testHandlers;
  final String overallStatus;
  final String leaderName;
  List<ResponsibleDetailModel> responsibleDetails;
  final DateTime applyDateTime;
  final String rawExpectedCompletionTime;

  String? fileUrl;
  String? fileName;
  String? fileType;
  int? fileSize;
  String? fileUploadTime;
  String? applicantId;

  // 🔥 关键修改：移除 final，允许运行时更新
  List<FileModel> applyFiles;
  final String customContent;

  ApplyModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.customer,
    required this.business,
    required this.expectedCompletionTime,
    required this.applyTime,
    required this.applicant,
    required this.hardwareHandlers,
    required this.softwareHandlers,
    required this.testHandlers,
    required this.overallStatus,
    required this.leaderName,
    required this.responsibleDetails,
    required this.applyDateTime,
    required this.rawExpectedCompletionTime,
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.fileSize,
    this.fileUploadTime,
    this.applicantId,
    // 🔥 初始化开案文件列表
    this.applyFiles = const [],
    this.customContent = '',
  });

  factory ApplyModel.fromJson(Map<String, dynamic> json) {
    String userIdStr = '';
    String userNameStr = '';
    if (json['userId'] != null) {
      if (json['userId'] is Map) {
        userIdStr = json['userId']['_id'] ?? '';
        userNameStr = json['userId']['username'] ?? '未知用户';
      } else if (json['userId'] is String) {
        userIdStr = json['userId'] ?? '';
        userNameStr = json['userName'] ?? '未知用户';
      }
    } else {
      userIdStr = json['_id'] ?? '';
      userNameStr = json['userName'] ?? '未知用户';
    }


    List<String> hardwareHandlers = [];
    List<String> softwareHandlers = [];
    List<String> testHandlers = [];
    List<ResponsibleDetailModel> responsibleDetails = [];

    if (json['responsibles'] != null && json['responsibles'] is List) {
      for (var resp in json['responsibles']) {
        String role = resp['role'] ?? '';
        String username = resp['username'] ?? '';

        ResponsibleDetailModel detailModel = ResponsibleDetailModel.fromJson(resp);
        responsibleDetails.add(detailModel);

        if (username.isNotEmpty) {
          switch (role) {
            case 'hardware':
              hardwareHandlers.add(username);
              break;
            case 'software':
              softwareHandlers.add(username);
              break;
            case 'test':
              testHandlers.add(username);
              break;
          }
        }
      }
    }

    // 修复：强制使用北京时间格式化
    String formatDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return '';
      try {
        // 先解析为UTC时间，再转换为北京时间
        DateTime utcDate;
        if (dateStr.contains('T')) {
          utcDate = DateTime.parse(dateStr).toUtc();
        } else if (dateStr.contains('/')) {
          utcDate = DateFormat('yyyy/MM/dd').parse(dateStr).toUtc();
        } else if (dateStr.contains('-')) {
          utcDate = DateFormat('yyyy-MM-dd').parse(dateStr).toUtc();
        } else {
          utcDate = DateFormat('yyyy-MM-dd HH:mm:ss').parseLoose(dateStr).toUtc();
        }
        // 转换为北京时间（UTC+8）
        DateTime beijingDate = utcDate.add(Duration(hours: 8));
        return DateFormat('yyyy-MM-dd').format(beijingDate);
      } catch (e) {
        dev.log('日期格式化失败：$e，原始字符串：$dateStr', name: '日期解析');
        return dateStr.split(' ').first ?? '';
      }
    }

    // 解析为北京时间的DateTime
    DateTime parseApplyDateTime(dynamic dateValue) {
      if (dateValue == null) return DateTime.now().toUtc().add(Duration(hours: 8));
      try {
        DateTime utcDate;
        if (dateValue is String) {
          utcDate = DateTime.parse(dateValue).toUtc();
        } else if (dateValue is DateTime) {
          utcDate = dateValue.toUtc();
        } else {
          throw FormatException('不支持的日期类型');
        }
        // 转换为北京时间
        return utcDate.add(Duration(hours: 8));
      } catch (e) {
        String applyTimeStr = json['applyTime'] ?? '';
        if (applyTimeStr.isNotEmpty) {
          try {
            DateTime utcDate = DateFormat('yyyy-MM-dd HH:mm:ss').parseLoose(applyTimeStr).toUtc();
            return utcDate.add(Duration(hours: 8));
          } catch (e2) {
            return DateTime.now().toUtc().add(Duration(hours: 8));
          }
        }
      }
      return DateTime.now().toUtc().add(Duration(hours: 8));
    }

    String leaderName = json['leaderName'] ?? '未知组长';
    String overallStatus = ['not_started', 'in_progress', 'overdue', 'completed', 'paused','cancelled'].contains(json['overallStatus'])
        ? json['overallStatus']
        : 'not_started';
    String applyTimeStr = json['applyTime']?.toString() ?? '';
    String rawExpectedTime = json['expectedCompletionTime']?.toString() ?? '';
    String formattedExpectedTime = formatDate(rawExpectedTime);
    DateTime applyDateTime = parseApplyDateTime(json['applyDateTime'] ?? applyTimeStr);

    // 解析开案文件列表
    List<FileModel> applyFiles = [];
    if (json['applyFiles'] != null && json['applyFiles'] is List) {
      applyFiles = (json['applyFiles'] as List)
          .map((fileJson) => FileModel.fromJson(fileJson))
          .toList();
    }

    // 创建 ApplyModel 实例（🔥 关键：传递 applyFiles 参数）
    ApplyModel model = ApplyModel(
      id: json['_id'] ?? '',
      userId: userIdStr,
      userName: userNameStr,
      customer: json['customer'] ?? '',
      business: json['business'] ?? '',
      expectedCompletionTime: formattedExpectedTime,
      applyTime: formatDate(applyTimeStr),
      applicant: json['applicant'] ?? '未知申请人',
      hardwareHandlers: hardwareHandlers,
      softwareHandlers: softwareHandlers,
      testHandlers: testHandlers,
      overallStatus: overallStatus,
      leaderName: leaderName,
      responsibleDetails: responsibleDetails,
      applyDateTime: applyDateTime,
      rawExpectedCompletionTime: rawExpectedTime,
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      fileType: json['fileType'],
      fileSize: json['fileSize'],
      fileUploadTime: json['fileUploadTime'] != null ? formatToBeijingTime(json['fileUploadTime']) : null,
      applicantId: json['applicantId'] ?? json['userId'] ?? '',
      // 🔥 关键：赋值开案文件列表
      applyFiles: applyFiles,
      customContent: json['customContent'] ?? '',
    );

    return model;
  }

  String get overallStatusCn {
    switch (overallStatus) {
      case 'not_started':
        return '未开始';
      case 'in_progress':
        return '进行中';
      case 'overdue':
        return '已逾期';
      case 'completed':
        return '已完成';
      case 'paused':
        return '已暂停';
      case 'cancelled': // 新增
        return '已取消';
      default:
        return '未知状态';
    }
  }

  // 修复：基于北京时间计算逾期天数
  int get overdueDays {
    if (overallStatus != 'overdue') return 0;

    if (expectedCompletionTime.isEmpty) {
      dev.log('预计完成时间为空，无法计算逾期天数：$rawExpectedCompletionTime', name: '逾期计算');
      return 0;
    }

    try {
      // 解析预计完成时间为北京时间
      DateTime expectedDate = DateFormat('yyyy-MM-dd').parse(expectedCompletionTime);
      // 获取当前北京时间
      DateTime nowBeijing = DateTime.now().toUtc().add(Duration(hours: 8));
      int days = nowBeijing.difference(expectedDate).inDays;
      dev.log('逾期天数计算（北京时间）：预计$expectedCompletionTime，当前${DateFormat('yyyy-MM-dd').format(nowBeijing)}，逾期$days天', name: '逾期计算');
      return days > 0 ? days : 0;
    } catch (e) {
      dev.log('逾期天数计算失败：$e，预计完成时间：$expectedCompletionTime', name: '逾期计算');
      return 0;
    }
  }

  // 修复：强化逾期状态颜色显示
  Color get overallStatusColor {
    if (overallStatus == 'overdue') {
      int days = overdueDays;
      double red = 211 / 255;
      double green = days > 30 ? 47 / 255 : (47 + (30 - days) * 2) / 255;
      double blue = 47 / 255;
      double opacity = days > 30 ? 1.0 : (0.3 + days * 0.023);
      return Color.fromRGBO((red * 255).toInt(), (green * 255).toInt(), (blue * 255).toInt(), opacity.clamp(0.3, 1.0));
    }
    switch (overallStatus) {
      case 'not_started':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'paused':
        return Colors.yellow;
      case 'cancelled': // 新增
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  double get completionProgress {
    if (responsibleDetails.isEmpty) return 0.0;
    int completedCount = responsibleDetails.where((d) => d.personalStatus == 'completed').length;
    return completedCount / responsibleDetails.length;
  }

  void updateResponsibleDetails(List<ResponsibleDetailModel> newDetails) {
    responsibleDetails = newDetails;
  }
}

// FileModel 补充 fileSize 字段和 fromJson 构造函数
class FileModel {
  final String fileName;
  final String fileType;
  final String fileUrl;
  final String uploadTime;
  final int fileSize;

  FileModel({
    required this.fileName,
    required this.fileType,
    required this.fileUrl,
    required this.uploadTime,
    this.fileSize = 0,
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      fileName: json['fileName'] ?? '',
      fileType: json['fileType'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
      uploadTime: json['uploadTime'] != null ? formatToBeijingTime(json['uploadTime']) : '',
      fileSize: json['fileSize'] ?? 0,
    );
  }
}

// 通用工具方法：将任意时间字符串转换为北京时间格式
String formatToBeijingTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  try {
    DateTime utcDate = DateTime.parse(dateStr).toUtc();
    DateTime beijingDate = utcDate.add(Duration(hours: 8));
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(beijingDate);
  } catch (e) {
    dev.log('转换北京时间失败：$e，原始字符串：$dateStr', name: '时间转换');
    return dateStr;
  }
}