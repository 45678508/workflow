import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'apply_model.dart';
import 'package:workflow/constants/api_constants.dart';

class ApplyDetailApiService {
  // 获取用户在当前申请中的测试角色权限
  static Future<bool> getTestRolePermission(String applyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? '';

      Uri uri = Uri.parse('$baseUrl/api/public/get-user-role-in-apply/$applyId');
      http.Response response = await http.get(
          uri,
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}
      );

      Map<String, dynamic> result = json.decode(response.body);
      if (response.statusCode == 200 && result['success'] == true) {
        return result['data']['role'] == 'test';
      }
    } catch (e) {
      dev.log('初始化测试角色权限失败: $e');
    }
    return false;
  }

  // 获取申请详情数据
  static Future<Map<String, dynamic>?> fetchApplyDetail(String applyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final response = await http.get(
        Uri.parse('$baseUrl/api/public/get-apply-detail/$applyId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return data['data'];
        }
      }
    } catch (e) {
      dev.log('获取任务详情失败: $e');
    }
    return null;
  }

  // 保存任务内容
  // apply_detail_api_service.dart 中 saveTaskContent 方法定义
  static Future<Map<String, dynamic>> saveTaskContent(
      String applyId,
      String targetUserId,
      String content, { // 注意这里的大括号，表示命名参数
        bool shouldCreateRecord = false, // 可选命名参数，带默认值
      }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? '';

      http.Response response = await http.post(
          Uri.parse('$baseUrl/api/public/update-task-content/$applyId'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: json.encode({
            'taskContent': content,
            'targetUserId': targetUserId,
            'shouldCreateRecord': shouldCreateRecord,
          })
      );

      return json.decode(response.body);
    } catch (e) {
      dev.log('保存任务内容异常: $e');
      return {
        'success': false,
        'msg': '保存失败: $e'
      };
    }
  }

  // 保存测试反馈
  static Future<Map<String, dynamic>> saveTestFeedback(
      String applyId,
      String targetUserId,
      String content
      ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? '';

      http.Response response = await http.post(
        Uri.parse('$baseUrl/api/public/save-test-feedback/$applyId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: json.encode({
          'targetUserId': targetUserId,
          'content': content,
        }),
      );

      return json.decode(response.body);
    } catch (e) {
      dev.log('保存测试反馈异常: $e');
      return {
        'success': false,
        'msg': '保存失败: $e'
      };
    }
  }

  // 更新个人任务状态
  static Future<Map<String, dynamic>> updatePersonalStatus(
      String applyId,
      String targetUserId,
      String newStatus
      ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      String apiUrl = '';
      if (newStatus == 'in_progress') {
        apiUrl = '$baseUrl/api/set-task-in-progress/$applyId';
      } else if (newStatus == 'completed') {
        apiUrl = '$baseUrl/api/complete-personal-task/$applyId';
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'targetUserId': targetUserId}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      dev.log('更新个人任务状态异常: $e');
      return {
        'success': false,
        'msg': '网络错误: $e'
      };
    }
  }

  // 更新整体任务状态
  static Future<Map<String, dynamic>> updateOverallStatus(
      String applyId,
      String newStatus
      ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/api/public/update-apply-overall-status/$applyId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'targetOverallStatus': newStatus,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      dev.log('更新整体任务状态异常: $e');
      return {
        'success': false,
        'msg': '网络错误: $e'
      };
    }
  }

  // 测试不合格，重置任务状态
  static Future<Map<String, dynamic>> resetResponsibleStatus(
      String applyId,
      String targetUserId,
      String reason
      ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? '';

      http.Response response = await http.post(
          Uri.parse('$baseUrl/api/public/reset-responsible-status/$applyId'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: json.encode({
            'targetUserId': targetUserId,
            'reason': reason,
          })
      );

      return json.decode(response.body);
    } catch (e) {
      dev.log('重置任务状态异常: $e');
      return {
        'success': false,
        'msg': '重置失败: $e'
      };
    }
  }

  // 获取任务内容历史记录
  static Future<Map<String, dynamic>> getTaskContentHistory(
      String applyId,
      String targetUserId
      ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? '';

      Uri uri = Uri.parse('$baseUrl/api/public/get-task-content-history/$applyId/$targetUserId');
      http.Response response = await http.get(
          uri,
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}
      );

      return json.decode(response.body);
    } catch (e) {
      dev.log('获取任务内容历史失败: $e');
      return {
        'success': false,
        'data': {
          'canEdit': true,
          'history': []
        }
      };
    }
  }

  // 上传任务文件
  static Future<Map<String, dynamic>> uploadTaskFile(
      String applyId,
      String targetUserId,
      FilePickerResult fileResult
      ) async {
    try {
      // 安全处理文件路径
      if (fileResult.files.single.path == null) {
        return {
          'success': false,
          'msg': '文件路径获取失败，请检查文件权限'
        };
      }

      File file = File(fileResult.files.single.path!);

      // 检查文件是否存在
      if (!await file.exists()) {
        return {
          'success': false,
          'msg': '文件不存在，请重新选择'
        };
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // 创建multipart请求
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/public/upload-task-file/$applyId'),
      );

      // 添加请求头
      request.headers['Authorization'] = 'Bearer $token';

      // 添加表单字段
      request.fields['targetUserId'] = targetUserId;
      request.fields['fileName'] = fileResult.files.single.name;

      // 获取文件MIME类型
      String mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      request.fields['fileType'] = mimeType;

      // 添加文件
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileResult.files.single.name,
          contentType: http.MediaType.parse(mimeType),
        ),
      );

      // 详细日志记录
      dev.log('开始上传文件：${fileResult.files.single.name}，大小：${await file.length()}字节');

      // 发送请求
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var data = jsonDecode(responseData);

      dev.log('上传响应：状态码=${response.statusCode}，数据=$data');

      return data;
    } catch (e) {
      dev.log('文件上传异常：$e');
      return {
        'success': false,
        'msg': '文件上传失败: ${e.toString()}'
      };
    }
  }

  // 删除任务文件
  static Future<Map<String, dynamic>> deleteTaskFile(
      String applyId,
      String targetUserId,
      String fileUrl
      ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/api/public/delete-task-file/$applyId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'targetUserId': targetUserId,
          'fileUrl': fileUrl,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      dev.log('删除文件异常: $e');
      return {
        'success': false,
        'msg': '网络错误: $e'
      };
    }
  }
}