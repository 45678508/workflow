import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:intl/intl.dart';
import '../../../constants/api_constants.dart';

// 申请单操作API封装
class ApplyOverallApi {
  // 更新申请单整体状态
  static Future<Map<String, dynamic>> updateOverallStatus({
    required String applyId,
    required String targetOverallStatus,
    required String token,
  }) async {
    try {
      // 修复：调用组长接口而不是公共接口
      final url = '$baseUrl/api/leader/update-overall-status/$applyId';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          // 修复：参数名从 targetOverallStatus 改为 targetStatus
          'targetStatus': targetOverallStatus,
        }),
      );

      final result = json.decode(response.body);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'msg': result['msg'] ?? '状态更新失败',
        };
      }
      return result;
    } catch (e) {
      dev.log('更新申请单整体状态请求异常：$e');
      return {
        'success': false,
        'msg': '网络异常：$e',
      };
    }
  }

  // 修改申请单预计完成时间
  static Future<Map<String, dynamic>> updateExpectedCompletionTime({
    required String applyId,
    required String newExpectedCompletionTime,
    required String token,
  }) async {
    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      try {
        dateFormat.parse(newExpectedCompletionTime);
      } catch (e) {
        return {
          'success': false,
          'msg': '日期格式错误，请使用 yyyy-MM-dd 格式',
        };
      }

      final url = '$baseUrl/api/public/update-apply-expected-time/$applyId';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'newExpectedCompletionTime': newExpectedCompletionTime,
        }),
      );

      final result = json.decode(response.body);
      if (response.statusCode != 200) {
        return {
          'success': false,
        };
      }
      return result;
    } catch (e) {
      dev.log('修改预计完成时间请求异常：$e');
      return {
        'success': false,
      };
    }
  }

  // 刷新申请单详情
  static Future<Map<String, dynamic>> refreshApplyDetail({
    required String applyId,
    required String token,
  }) async {
    try {
      final url = '$baseUrl/api/public/get-apply-detail/$applyId';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      dev.log('接口响应状态码：${response.statusCode}', name: 'ApplyOverallApi.refreshApplyDetail');
      dev.log('接口完整响应体：${response.body}', name: 'ApplyOverallApi.refreshApplyDetail');

      final result = json.decode(response.body);
      dev.log('【后端完整响应】applyId: $applyId，数据：$result', name: 'ApplyOverallApi.refreshApplyDetail');

      if (response.statusCode != 200) {
        return {
          'success': false,
        };
      }
      return result;
    } catch (e) {
      dev.log('刷新任务详情请求异常：$e');
      return {
        'success': false,
      };
    }
  }

  // 更新任务内容API
  static Future<Map<String, dynamic>> updateTaskContent({
    required String applyId,
    required String taskContent,
    required String token,
    String? targetUserId,
  }) async {
    try {
      final url = '$baseUrl/api/public/update-task-content/$applyId';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'taskContent': taskContent,
          if (targetUserId != null) 'targetUserId': targetUserId,
        }),
      );

      final result = json.decode(response.body);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'msg': '请求失败，状态码：${response.statusCode}',
        };
      }
      return result;
    } catch (e) {
      dev.log('更新任务内容请求异常：$e');
      return {
        'success': false,
        'msg': '网络异常：$e',
      };
    }
  }

  // 重置负责人状态为进行中
  static Future<Map<String, dynamic>> resetResponsibleStatus({
    required String applyId,
    required String targetUserId,
    required String token,
  }) async {
    try {
      final url = '$baseUrl/api/public/reset-responsible-status/$applyId';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'targetUserId': targetUserId,
        }),
      );

      final result = json.decode(response.body);
      if (response.statusCode != 200) {
        return {
          'success': false,
        };
      }
      return result;
    } catch (e) {
      dev.log('重置负责人状态请求异常：$e');
      return {
        'success': false,
      };
    }
  }

  // 新增负责人API
  static Future<Map<String, dynamic>> addResponsible({
    required String applyId,
    required String username,
    required String role,
    required String token,
  }) async {
    try {
      final url = '$baseUrl/api/public/add-responsible/$applyId';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'username': username,
          'role': role,
        }),
      );

      final result = json.decode(response.body);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'msg': '请求失败，状态码：${response.statusCode}',
        };
      }
      return result;
    } catch (e) {
      dev.log('添加负责人请求异常：$e');
      return {
        'success': false,
        'msg': '网络异常：$e',
      };
    }
  }

  // 组长布置任务内容（设置leaderContent）
  static Future<Map<String, dynamic>> setLeaderContent({
    required String applyId,
    required String targetUserId,
    required String leaderContent,
    required String token,
  }) async {
    try {
      final url = '$baseUrl/api/leader/set-leader-content/$applyId';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'targetUserId': targetUserId,
          'leaderContent': leaderContent,
        }),
      );

      final result = json.decode(response.body);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'msg': result['msg'] ?? '布置任务内容失败',
        };
      }
      return result;
    } catch (e) {
      dev.log('布置任务内容请求异常：$e');
      return {
        'success': false,
        'msg': '网络异常：$e',
      };
    }
  }

// 组长上传任务文件（支持拖拽）
  static Future<Map<String, dynamic>> uploadLeaderTaskFile({
    required String applyId,
    required String targetUserId,
    required String filePath,
    required String token,
  }) async {
    try {
      final url = '$baseUrl/api/leader/upload-task-file/$applyId';

      // 创建multipart请求
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['targetUserId'] = targetUserId
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final result = json.decode(responseBody);

      if (response.statusCode != 200) {
        return {
          'success': false,
          'msg': result['msg'] ?? '文件上传失败',
        };
      }
      return result;
    } catch (e) {
      dev.log('组长上传任务文件请求异常：$e');
      return {
        'success': false,
        'msg': '网络异常：$e',
      };
    }
  }
  // 组长删除自己上传的任务文件
  static Future<Map<String, dynamic>> deleteLeaderTaskFile({
    required String applyId,
    required String targetUserId,
    required String fileUrl,
    required String token,
  }) async {
    try {
      final url = '$baseUrl/api/leader/delete-leader-file/$applyId';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'targetUserId': targetUserId,
          'fileUrl': fileUrl,
        }),
      );

      final result = json.decode(response.body);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'msg': result['msg'] ?? '删除文件失败',
        };
      }
      return result;
    } catch (e) {
      dev.log('组长删除任务文件请求异常：$e');
      return {
        'success': false,
        'msg': '网络异常：$e',
      };
    }
  }

  // ApplyOverallApi类中新增：获取所有用户列表（用于负责人选择下拉）
  static Future<Map<String, dynamic>> getAllUsers({required String token}) async {
    try {
      final url = '$baseUrl/api/public/users';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final result = json.decode(response.body);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'msg': result['msg'] ?? '获取用户列表失败',
        };
      }
      return result;
    } catch (e) {
      dev.log('获取用户列表请求异常：$e');
      return {
        'success': false,
        'msg': '网络异常：$e',
      };
    }
  }
}

