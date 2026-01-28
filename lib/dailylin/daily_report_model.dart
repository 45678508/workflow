// 日报数据模型
class DailyReportModel {
  final String? id;
  final String userId;
  final String date;
  final String name;
  final String department;
  final String position;
  final List<WorkItem> todayWork;
  final List<WorkItem> tomorrowPlan;
  final List<UnfinishedItem> unfinishedWork;
  final int selfEvaluation;
  final String summary;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyReportModel({
    this.id,
    required this.userId,
    required this.date,
    required this.name,
    required this.department,
    required this.position,
    required this.todayWork,
    required this.tomorrowPlan,
    required this.unfinishedWork,
    required this.selfEvaluation,
    required this.summary,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': date,
      'name': name,
      'department': department,
      'position': position,
      'todayWork': todayWork.map((item) => item.toMap()).toList(),
      'tomorrowPlan': tomorrowPlan.map((item) => item.toMap()).toList(),
      'unfinishedWork': unfinishedWork.map((item) => item.toMap()).toList(),
      'selfEvaluation': selfEvaluation,
      'summary': summary,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory DailyReportModel.fromMap(Map<String, dynamic> map) {
    return DailyReportModel(
      id: map['_id']?.toString(),
      userId: map['userId'],
      date: map['date'],
      name: map['name'],
      department: map['department'],
      position: map['position'],
      todayWork: (map['todayWork'] as List<dynamic>)
          .map((item) => WorkItem.fromMap(item))
          .toList(),
      tomorrowPlan: (map['tomorrowPlan'] as List<dynamic>)
          .map((item) => WorkItem.fromMap(item))
          .toList(),
      unfinishedWork: (map['unfinishedWork'] as List<dynamic>)
          .map((item) => UnfinishedItem.fromMap(item))
          .toList(),
      selfEvaluation: map['selfEvaluation'],
      summary: map['summary'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  // 空日报模板
  factory DailyReportModel.empty(
    String userId,
    String date,
    String name,
    String department,
    String position,
  ) {
    return DailyReportModel(
      userId: userId,
      date: date,
      name: name,
      department: department,
      position: position,
      todayWork: [],
      tomorrowPlan: [],
      unfinishedWork: [],
      selfEvaluation: 80,
      summary: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

// 工作项模型
class WorkItem {
  final int serial;
  final String timeRange;
  final String importance;
  final String content;
  final String output;

  WorkItem({
    required this.serial,
    required this.timeRange,
    required this.importance,
    required this.content,
    required this.output,
  });

  Map<String, dynamic> toMap() {
    return {
      'serial': serial,
      'timeRange': timeRange,
      'importance': importance,
      'content': content,
      'output': output,
    };
  }

  factory WorkItem.fromMap(Map<String, dynamic> map) {
    return WorkItem(
      serial: map['serial'],
      timeRange: map['timeRange'],
      importance: map['importance'],
      content: map['content'],
      output: map['output'],
    );
  }
}

// 未完成工作项模型
class UnfinishedItem {
  final int serial;
  final String workContent;
  final String reason;
  final String improvement;

  UnfinishedItem({
    required this.serial,
    required this.workContent,
    required this.reason,
    required this.improvement,
  });

  Map<String, dynamic> toMap() {
    return {
      'serial': serial,
      'workContent': workContent,
      'reason': reason,
      'improvement': improvement,
    };
  }

  factory UnfinishedItem.fromMap(Map<String, dynamic> map) {
    return UnfinishedItem(
      serial: map['serial'],
      workContent: map['workContent'],
      reason: map['reason'],
      improvement: map['improvement'],
    );
  }
}
