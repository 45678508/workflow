import 'package:flutter/material.dart';

// 负责人角色枚举
enum DetailResponsibleRole {
  software,
  hardware,
  test,
}

extension DetailResponsibleRoleExtension on DetailResponsibleRole {
  String get chineseName {
    switch (this) {
      case DetailResponsibleRole.software:
        return '软件';
      case DetailResponsibleRole.hardware:
        return '硬件';
      case DetailResponsibleRole.test:
        return '测试';
    }
  }
}