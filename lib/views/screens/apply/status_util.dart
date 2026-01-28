import 'package:flutter/material.dart';

// 状态处理工具类
class StatusUtil {
  // 状态字符串转中文名称
  static String getStatusChinese(String status) {
    switch (status) {
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
      case 'cancelled': // 新增
        return '已取消';
      default:
        return '未知状态';
    }
  }

  // 状态字符串转颜色
  static Color getStatusColor(String status) {
    switch (status) {
      case 'not_started':
        return Colors.orangeAccent;
      case 'in_progress':
        return Colors.blueAccent;
      case 'overdue':
        return Colors.redAccent;
      case 'completed':
        return Colors.greenAccent;
      case 'paused':
        return Colors.grey;
      case 'cancelled': // 新增
        return Color(0xFF999999);
      default:
        return const Color(0xFF86909C);
    }
  }

  // 状态切换提示文本
  static String getStatusTip(String status) {
    switch (status) {
      case 'completed':
        return '将同步所有负责人状态为「已完成」并填充完成时间';
      case 'paused':
        return '将同步所有未完成负责人状态为「暂停」';
      case 'in_progress':
        return '将同步所有暂停/逾期负责人状态为「进行中」';
      case 'cancelled': // 新增
        return '取消后任务将暂停所有进度，可重新恢复';
      default:
        return '无特殊联动效果';
    }
  }
}