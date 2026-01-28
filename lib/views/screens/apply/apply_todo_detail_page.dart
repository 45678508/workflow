import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'responsible_role_enum.dart';
import 'apply_models.dart';
import 'status_util.dart';
import 'common_utils.dart';
import 'apply_overall_api.dart';

// 导入文件操作相关工具
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';

// 定义样式常量 - 统一管理颜色和尺寸
const Color primaryColor = Color(0xFF165DFF); // 主色调优化
const Color primaryLightColor = Color(0xFFE8F3FF);
const Color successColor = Color(0xFF00B42A);
const Color warningColor = Color(0xFFFF7D00);
const Color dangerColor = Color(0xFFFF4D4F);
const Color neutralColor6 = Color(0xFF86909C);
const Color neutralColor2 = Color(0xFFF2F3F5);

// 申请单详情页
class ApplyTodoDetailPage extends StatefulWidget {
  final DetailApplyTodoModel todo;
  final VoidCallback onResponsibleAdded;

  const ApplyTodoDetailPage({
    super.key,
    required this.todo,
    required this.onResponsibleAdded,
  });

  @override
  State<ApplyTodoDetailPage> createState() => _ApplyTodoDetailPageState();
}

class _ApplyTodoDetailPageState extends State<ApplyTodoDetailPage> {
  bool _isAddingResponsible = false;
  bool _isOperatingOverallStatus = false;
  final TextEditingController _usernameController = TextEditingController();
  DetailResponsibleRole _selectedRole = DetailResponsibleRole.software;

  // ========== 新增：用户列表相关状态（仅添加这3个变量） ==========
  List<Map<String, String>> _allUserList = []; // 存储所有用户{id: '', username: ''}
  bool _isLoadingUsers = false; // 用户列表加载状态
  String? _selectedUsername; // 选中的用户名（关联下拉选择）

  late String _currentUserId;
  late String _currentUserTeamRole;
  late String _currentUserRole;
  late List<DetailTaskPerson> _localResponsibles;
  late DetailApplyTodoModel _currentTodo;
  late List<ApplyFile> _applyFiles;
  // 新增：存储申请人自定义内容
  late String _customContent;

  // 存储每个负责人的任务内容编辑控制器
  late Map<String, TextEditingController> _taskContentControllers;
  // 存储每个负责人的组长布置任务内容控制器
  late Map<String, TextEditingController> _leaderContentControllers;
  // 存储加载状态
  late Map<String, bool> _taskContentLoadingStates;
  // 存储组长布置任务内容的加载状态
  late Map<String, bool> _leaderContentLoadingStates;
  // 存储文件上传加载状态
  late Map<String, bool> _fileUploadLoadingStates;
  // 存储文件删除加载状态
  late Map<String, bool> _fileDeleteLoadingStates;

  // 可操作的状态列表
  final List<String> _availableStatusList = [
    'not_started',
    'in_progress',
    'overdue',
    'completed',
    'paused',
    'cancelled',
  ];

  bool _isUserInfoLoaded = false;

  @override
  void initState() {
    super.initState();
    _currentTodo = widget.todo;
    _applyFiles = widget.todo.applyFiles;
    // 初始化申请人自定义内容
    _customContent = (widget.todo as dynamic).customContent ?? '';
    _getCurrentUserInfo();
    _localResponsibles = List.from(widget.todo.responsibles);

    // 初始化任务内容控制器
    _taskContentControllers = {};
    _taskContentLoadingStates = {};

    // 初始化组长布置任务内容控制器
    _leaderContentControllers = {};
    _leaderContentLoadingStates = {};
    _fileUploadLoadingStates = {};
    _fileDeleteLoadingStates = {};

    for (var resp in _localResponsibles) {
      _taskContentControllers[resp.userId] = TextEditingController(
          text: resp.taskContent ?? '暂无任务内容'
      );
      _taskContentLoadingStates[resp.userId] = false;

      // 初始化组长布置任务内容控制器
      _leaderContentControllers[resp.userId] = TextEditingController(
          text: (resp as dynamic).leaderContent ?? '暂无'
      );
      _leaderContentLoadingStates[resp.userId] = false;
      _fileUploadLoadingStates[resp.userId] = false;
      _fileDeleteLoadingStates[resp.userId] = false;
    }

    _initUserDataAndRefresh();
    _loadAllUserList();
  }

  // 合并用户信息获取和数据刷新
  Future<void> _initUserDataAndRefresh() async {
    await _getCurrentUserInfo();
    if (mounted) {
      setState(() {
        _isUserInfoLoaded = true;
      });
      await _refreshApplyData();
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    // 释放所有任务内容控制器
    _taskContentControllers.forEach((key, controller) => controller.dispose());
    // 释放组长布置任务内容控制器
    _leaderContentControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  // 获取当前登录用户信息
  Future<void> _getCurrentUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('currentUserId') ?? '';
    _currentUserTeamRole = prefs.getString('teamRole') ?? '';
    _currentUserRole = prefs.getString('role') ?? '';
  }

  // 刷新申请单数据
  Future<void> _refreshApplyData() async {
    if (!mounted) return;
    setState(() => _isOperatingOverallStatus = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) throw Exception('未获取到登录信息，请重新登录');

      final result = await ApplyOverallApi.refreshApplyDetail(
        applyId: _currentTodo.id,
        token: token,
      );

      if (result['success'] == true) {
        final data = result['data'];
        final newResponsibles = (data['responsibles'] as List<dynamic>).map((item) {
          // 解析负责人文件
          List<ApplyFile> files = [];
          if (item['files'] is List) {
            files = (item['files'] as List).map((f) => ApplyFile.fromJson(f)).toList();
          }

          // 解析组长文件
          List<ApplyFile> leaderfiles = [];
          if (item['leaderfiles'] is List) {
            leaderfiles = (item['leaderfiles'] as List).map((f) => ApplyFile.fromJson(f)).toList();
          }

          return DetailTaskPerson(
            role: item['role'] ?? '',
            userId: item['userId'] ?? '',
            username: item['username'] ?? '',
            personalStatus: item['personalStatus'] ?? 'not_started',
            taskContent: item['taskContent'],
            leaderContent: item['leaderContent'],
            startTime: item['startTime'],
            completeTime: item['completeTime'],
            files: files,
            leaderfiles: leaderfiles, // 添加组长文件
          );
        }).toList();

        // 解析开案文件
        List<ApplyFile> newApplyFiles = [];
        if (data['applyFiles'] is List) {
          newApplyFiles = (data['applyFiles'] as List).map((f) => ApplyFile.fromJson(f)).toList();
        }

        final String backendOverallStatus = data['overallStatus'] ?? _currentTodo.overallStatus;

        if (mounted) {
          setState(() {
            _currentTodo = DetailApplyTodoModel(
              id: data['_id'] ?? _currentTodo.id,
              customer: data['customer'] ?? _currentTodo.customer,
              business: data['business'] ?? _currentTodo.business,
              applicant: data['applicant'] ?? _currentTodo.applicant,
              applyTime: DateTime.parse(data['applyTime'] ?? _currentTodo.applyTime.toString()),
              leaderName: data['leaderName'] ?? _currentTodo.leaderName,
              expectedCompletionTime: DateTime.parse(data['expectedCompletionTime'] ?? _currentTodo.expectedCompletionTime.toString()),
              responsibles: newResponsibles,
              overallStatus: backendOverallStatus,
              applyFiles: newApplyFiles,
              // 新增：刷新自定义内容
              customContent: data['customContent'] ?? '',
            );
            // 更新自定义内容
            _customContent = data['customContent'] ?? '';
            _localResponsibles = newResponsibles;
            _applyFiles = newApplyFiles;

            // 更新任务内容控制器
            for (var resp in newResponsibles) {
              if (_taskContentControllers.containsKey(resp.userId)) {
                _taskContentControllers[resp.userId]?.text = resp.taskContent ?? '暂无任务内容';
              } else {
                _taskContentControllers[resp.userId] = TextEditingController(
                    text: resp.taskContent ?? '暂无任务内容'
                );
                _taskContentLoadingStates[resp.userId] = false;
              }

              // 更新组长布置任务内容控制器
              if (_leaderContentControllers.containsKey(resp.userId)) {
                _leaderContentControllers[resp.userId]?.text = resp.leaderContent ?? '暂无';
              } else {
                _leaderContentControllers[resp.userId] = TextEditingController(
                    text: resp.leaderContent ?? '暂无'
                );
                _leaderContentLoadingStates[resp.userId] = false;
                _fileUploadLoadingStates[resp.userId] = false;
                _fileDeleteLoadingStates[resp.userId] = false;
              }
            }
          });
        }
        dev.log('刷新申请单数据成功，最新整体状态：$backendOverallStatus', name: '_refreshApplyData');
        widget.onResponsibleAdded();
      } else {
        _showSnackBar(result['msg'] ?? '刷新申请单数据失败', warningColor);
      }
    } catch (e) {
      dev.log('刷新申请单数据异常：$e');
      _showSnackBar('网络异常：$e', dangerColor);
    } finally {
      if (mounted) setState(() => _isOperatingOverallStatus = false);
    }
  }

  // ========== 新增：加载系统所有用户列表方法 ==========
  // ========== 加载系统所有用户列表方法（最终修复版） ==========
  Future<void> _loadAllUserList() async {
    if (!mounted) return;
    setState(() => _isLoadingUsers = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) throw Exception('未获取到登录信息，请重新登录');

      final result = await ApplyOverallApi.getAllUsers(token: token);
      if (result['success'] == true) {
        final List<dynamic> data = result['data'];
        setState(() {
          _allUserList = data.map((user) {
            // 显式类型转换：dynamic -> String，避免类型不匹配
            return {
              'id': (user['_id'] ?? '').toString(),
              'username': (user['username'] ?? '').toString(),
            };
            // 空安全过滤：仅保留用户名非空的用户，解决String?无法访问isNotEmpty问题
          }).where((user) => user['username']?.isNotEmpty ?? false).toList();
        });
      } else {
        _showSnackBar(result['msg'] ?? '获取用户列表失败', warningColor);
      }
    } catch (e) {
      dev.log('加载用户列表异常：$e');
      _showSnackBar('加载用户列表失败：$e', dangerColor);
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }
// ==========================================================


  // 删除组长上传的任务文件
  Future<void> _deleteLeaderTaskFile(String applyId, String userId, String fileUrl, String fileName) async {
    // 显示确认弹窗
    final isConfirmed = await _showConfirmDialog(
      '确认删除文件',
      '你确定要删除文件「$fileName」吗？删除后将无法恢复。',
    );

    if (!isConfirmed) return;

    if (_fileDeleteLoadingStates[userId] == true) return;

    setState(() {
      _fileDeleteLoadingStates[userId] = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) throw Exception('未获取到登录信息，请重新登录');

      final result = await ApplyOverallApi.deleteLeaderTaskFile(
        applyId: applyId,
        targetUserId: userId,
        fileUrl: fileUrl,
        token: token,
      );

      if (result['success'] == true) {
        await _refreshApplyData();
        _showSnackBar('文件删除成功', successColor);
      } else {
        _showSnackBar(result['msg'] ?? '文件删除失败', dangerColor);
      }
    } catch (e) {
      dev.log('删除任务文件异常：$e');
      _showSnackBar('网络异常：$e', dangerColor);
    } finally {
      if (mounted) {
        setState(() {
          _fileDeleteLoadingStates[userId] = false;
        });
      }
    }
  }

  // 保存组长布置的任务内容
  Future<void> _saveLeaderContent(String applyId, String userId, String leaderContent) async {
    if (_leaderContentLoadingStates[userId] == true) return;

    setState(() {
      _leaderContentLoadingStates[userId] = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) throw Exception('未获取到登录信息，请重新登录');

      final result = await ApplyOverallApi.setLeaderContent(
        applyId: applyId,
        targetUserId: userId,
        leaderContent: leaderContent,
        token: token,
      );

      if (result['success'] == true) {
        await _refreshApplyData();
        _showSnackBar('组长任务内容保存成功', successColor);
      } else {
        _showSnackBar(result['msg'] ?? '组长任务内容保存失败', dangerColor);
      }
    } catch (e) {
      dev.log('保存组长任务内容异常：$e');
      _showSnackBar('网络异常：$e', dangerColor);
    } finally {
      if (mounted) {
        setState(() {
          _leaderContentLoadingStates[userId] = false;
        });
      }
    }
  }

  // 组长上传任务文件
  Future<void> _uploadLeaderTaskFile(String applyId, String userId, {File? dragFile}) async {
    if (_fileUploadLoadingStates[userId] == true) return;

    setState(() {
      _fileUploadLoadingStates[userId] = true;
    });

    File? fileToUpload;

    try {
      // 如果是拖拽文件，直接使用
      if (dragFile != null) {
        fileToUpload = dragFile;
      } else {
        // 选择文件
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );

        if (result == null || result.files.single.path == null) {
          setState(() {
            _fileUploadLoadingStates[userId] = false;
          });
          return;
        }
        fileToUpload = File(result.files.single.path!);
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) throw Exception('未获取到登录信息，请重新登录');

      // 上传文件
      final uploadResult = await ApplyOverallApi.uploadLeaderTaskFile(
        applyId: applyId,
        targetUserId: userId,
        filePath: fileToUpload!.path,
        token: token,
      );

      if (uploadResult['success'] == true) {
        await _refreshApplyData();
        _showSnackBar('文件上传成功', successColor);
      } else {
        _showSnackBar(uploadResult['msg'] ?? '文件上传失败', dangerColor);
      }
    } catch (e) {
      dev.log('上传任务文件异常：$e');
      _showSnackBar('网络异常：$e', dangerColor);
    } finally {
      if (mounted) {
        setState(() {
          _fileUploadLoadingStates[userId] = false;
        });
      }
    }
  }

  // 获取已存在的用户名列表
  List<String> _getExistingUsernames() {
    return _localResponsibles.map((resp) => resp.username.trim().toLowerCase()).toList();
  }

  // 新增负责人
  Future<void> _addtaskPerson() async {
    final String username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showSnackBar('请输入负责人用户名', warningColor);
      return;
    }

    // 校验同角色下是否有该用户
    final roleResponsibles = _localResponsibles.where((resp) => resp.role == _selectedRole.name).toList();
    final isDuplicate = roleResponsibles.any((resp) =>
    resp.username.trim().toLowerCase() == username.toLowerCase()
    );
    if (isDuplicate) {
      _showSnackBar('该用户已作为${_selectedRole.chineseName}负责人添加过', warningColor);
      return;
    }

    if (_isAddingResponsible) return;
    setState(() => _isAddingResponsible = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: primaryColor)),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) throw Exception('未获取到登录信息，请重新登录');

      final String applyId = widget.todo.id;
      final String role = _selectedRole.name;

      final result = await ApplyOverallApi.addResponsible(
        applyId: applyId,
        username: username,
        role: role,
        token: token,
      );

      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        await _refreshApplyData();
        _usernameController.clear();
        setState(() => _selectedRole = DetailResponsibleRole.software);
        widget.onResponsibleAdded();
      } else {
        _showSnackBar(result['msg'] ?? '添加负责人失败', dangerColor);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('网络异常：$e', dangerColor);
    } finally {
      if (mounted) setState(() => _isAddingResponsible = false);
    }
  }

  // 更新申请单整体状态
  Future<void> _updateOverallStatus(String targetStatus) async {
    if (_isOperatingOverallStatus || _currentTodo.overallStatus == targetStatus) return;

    final isConfirmed = await _showConfirmDialog(
      '确认修改任务状态',
      '你确定要将该任务状态修改为「${StatusUtil.getStatusChinese(targetStatus)}」吗？\n注：${StatusUtil.getStatusTip(targetStatus)}',
    );
    if (!isConfirmed) return;

    if (!mounted) return;
    setState(() => _isOperatingOverallStatus = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) throw Exception('未获取到登录信息，请重新登录');

      final result = await ApplyOverallApi.updateOverallStatus(
        applyId: _currentTodo.id,
        targetOverallStatus: targetStatus,
        token: token,
      );

      if (result['success'] == true) {
        await _refreshApplyData();
        _showSnackBar('状态更新成功', successColor);
      } else {
        _showSnackBar(result['msg'] ?? '状态更新失败', dangerColor);
      }
    } catch (e) {
      dev.log('修改申请单整体状态异常：$e');
      _showSnackBar('网络异常：$e', dangerColor);
    } finally {
      if (mounted) setState(() => _isOperatingOverallStatus = false);
    }
  }

  // 修改预计完成时间
  Future<void> _updateExpectedCompletionTime() async {
    if (_isOperatingOverallStatus) return;

    // 计算合理的起始日期
    final DateTime earliestDate = DateTime.now().subtract(const Duration(days: 7));
    // 确保初始日期不早于起始日期
    final DateTime safeInitialDate = _currentTodo.expectedCompletionTime.isBefore(earliestDate)
        ? earliestDate
        : _currentTodo.expectedCompletionTime;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: safeInitialDate,
      firstDate: earliestDate,
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          primaryColor: primaryColor,
          buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
        ),
        child: child!,
      ),
    );

    if (selectedDate == null) return;
    final newExpectedTime = DateFormat('yyyy-MM-dd').format(selectedDate);

    if (!mounted) return;
    setState(() => _isOperatingOverallStatus = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) throw Exception('未获取到登录信息，请重新登录');

      final result = await ApplyOverallApi.updateExpectedCompletionTime(
        applyId: _currentTodo.id,
        newExpectedCompletionTime: newExpectedTime,
        token: token,
      );

      if (result['success'] == true) {
        await _refreshApplyData();
        _showSnackBar('预计完成时间修改成功', successColor);
      } else {
        _showSnackBar(result['msg'] ?? '预计完成时间修改失败', dangerColor);
      }
    } catch (e) {
      dev.log('修改预计完成时间异常');
      _showSnackBar('网络异常：$e', dangerColor);
    } finally {
      if (mounted) setState(() => _isOperatingOverallStatus = false);
    }
  }

  // 按角色分组整理负责人列表
  Map<String, List<DetailTaskPerson>> _groupResponsiblesByRole() {
    final grouped = <String, List<DetailTaskPerson>>{
      'software': [],
      'hardware': [],
      'test': [],
    };

    for (final resp in _localResponsibles) {
      if (grouped.containsKey(resp.role)) {
        grouped[resp.role]!.add(resp);
      } else {
        dev.log('未知角色：${resp.role}，跳过该负责人分组', name: '_groupResponsiblesByRole');
      }
    }

    return grouped;
  }

  // 保存任务内容
  Future<void> _saveTaskContent(String applyId, String userId, String taskContent) async {
    if (_taskContentLoadingStates[userId] == true) return;

    setState(() {
      _taskContentLoadingStates[userId] = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) throw Exception('未获取到登录信息，请重新登录');

      final result = await ApplyOverallApi.updateTaskContent(
        applyId: applyId,
        taskContent: taskContent,
        token: token,
        targetUserId: userId,
      );

      if (result['success'] == true) {
        await _refreshApplyData();
        _showSnackBar('任务内容保存成功', successColor);
      } else {
        _showSnackBar(result['msg'] ?? '任务内容保存失败', dangerColor);
      }
    } catch (e) {
      dev.log('保存任务内容异常：$e');
      _showSnackBar('网络异常：$e', dangerColor);
    } finally {
      if (mounted) {
        setState(() {
          _taskContentLoadingStates[userId] = false;
        });
      }
    }
  }

  // 重置负责人状态为进行中
  Future<void> _resetToInProgress(String targetUserId) async {
    final isConfirmed = await _showConfirmDialog(
      '确认重置状态',
      '你确定要将该负责人的任务状态重置为「进行中」吗？重置后将清空完成时间（若有）。',
    );
    if (!isConfirmed) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) throw Exception('未获取到登录信息，请重新登录');

      final result = await ApplyOverallApi.resetResponsibleStatus(
        applyId: _currentTodo.id,
        targetUserId: targetUserId,
        token: token,
      );

      if (result['success'] == true) {
        await _refreshApplyData();
        _showSnackBar('状态重置成功', successColor);
      } else {
        _showSnackBar('状态重置失败', dangerColor);
      }
    } catch (e) {
      dev.log('重置状态异常：$e');
      _showSnackBar('网络异常：$e', dangerColor);
    }
  }

  // 弹窗确认通用方法
  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        content: Text(content),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: neutralColor6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            child: const Text('确认'),
          ),
        ],
      ),
    ) ?? false;
  }

  // 显示SnackBar提示
  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // 构建组长右上角下拉菜单
  Widget _buildLeaderPopupMenu() {
    // 过滤不可操作的状态
    final availableStatus = _availableStatusList.where((status) {
      return status != _currentTodo.overallStatus;
    }).toList();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      onSelected: (value) {
        if (value == 'update_time') {
          _updateExpectedCompletionTime();
        } else {
          _updateOverallStatus(value);
        }
      },
      itemBuilder: (context) => [
        ...availableStatus.map((status) => PopupMenuItem(
          value: status,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: StatusUtil.getStatusColor(status),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 8),
              Text('设置为${StatusUtil.getStatusChinese(status)}'),
            ],
          ),
        )),
        const PopupMenuDivider(),
        if (!['completed'].contains(_currentTodo.overallStatus))
          const PopupMenuItem(
            value: 'update_time',
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: primaryColor),
                SizedBox(width: 8),
                Text('修改预计完成时间'),
              ],
            ),
          ),
      ],
    );
  }

  // 格式化时间
  String formatTime(String timeStr) {
    try {
      DateTime dateTime = DateTime.parse(timeStr);

      // 将UTC时间转换为北京时间（UTC+8）
      if (timeStr.contains('T') || timeStr.endsWith('Z')) {
        dateTime = dateTime.add(const Duration(hours: 8));
      }
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    } catch (e) {
      return timeStr;
    }
  }

  // 格式化文件大小
  String _formatFileSize(int? size) {
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

  // 构建文件列表（添加删除功能）
  // 替换原有的 buildFileList 方法
  Widget buildFileList(List<ApplyFile> files, String title, BuildContext context, {String? userId}) {
    final isLeader = _currentUserTeamRole == '组长';

    if (files.isEmpty) {
      return const SizedBox.shrink();
    }

    // 处理userId空值问题，提供默认值
    final safeUserId = userId ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: neutralColor6,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: primaryLightColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryLightColor),
          ),
          child: Column(
            children: files.map((file) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryLightColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.insert_drive_file, color: primaryColor, size: 20),
                ),
                title: Text(
                  file.fileName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${formatFileSize(file.fileSize)} | ${formatTime(file.uploadTime ?? '')}',
                    style: const TextStyle(fontSize: 12, color: neutralColor6),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 仅组长可见删除按钮
                    if (isLeader && safeUserId.isNotEmpty && (title.contains('组长') || title.contains('任务文件')))
                      _fileDeleteLoadingStates[safeUserId] == true
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: dangerColor,
                          strokeWidth: 2,
                        ),
                      )
                          : IconButton(
                        icon: const Icon(Icons.delete_outline, color: dangerColor, size: 22),
                        onPressed: () => _deleteLeaderTaskFile(
                          _currentTodo.id,
                          safeUserId,
                          file.fileUrl,
                          file.fileName,
                        ),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    // 文件打开按钮
                    IconButton(
                      icon: const Icon(Icons.open_in_new, color: primaryColor, size: 22),
                      onPressed: () => openFile(file, context, onError: (msg) {
                        _showSnackBar(msg, dangerColor);
                      }),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
                onTap: () => openFile(file, context, onError: (msg) {
                  _showSnackBar(msg, dangerColor);
                }),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // 构建通用的保存按钮
  Widget _buildSaveButton({
    required bool isLoading,
    required VoidCallback onPressed,
    String text = '保存',
    double width = 80,
    double height = 32,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isLoading ? primaryColor.withOpacity(0.7) : primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryColor.withOpacity(0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
          elevation: 0,
          minimumSize: Size(width, height),
        ),
        child: isLoading
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todo = _currentTodo;
    final groupedResponsibles = _groupResponsiblesByRole();
    final isLeader = _currentUserTeamRole == '组长';

    // 加载中显示
    if (!_isUserInfoLoaded) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              const Text(
                '加载中...',
                style: TextStyle(color: neutralColor6, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务详情', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: primaryColor.withOpacity(0.2),
        actions: [
          if (isLeader) _buildLeaderPopupMenu(),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                const Text('任务状态：', style: TextStyle(fontSize: 14, color: neutralColor6)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: todo.overallStatusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: todo.overallStatusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    todo.overallStatusChinese,
                    style: TextStyle(
                      color: todo.overallStatusColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('申请单 #${todo.id.substring(todo.id.length - 6)}', style: TextStyle(fontSize: 14, color: neutralColor6)),
            const SizedBox(height: 12),
            Text('客户：${todo.customer}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.2)),
            const SizedBox(height: 12),
            Text('业务：${todo.business}', style: const TextStyle(fontSize: 16, color: Colors.black87)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryLightColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '申请人：${todo.applicant} | 提交时间：${DateFormat('yyyy-MM-dd').format(todo.applyTime)}',
                    style: TextStyle(color: neutralColor6, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '预计完成时间：${DateFormat('yyyy-MM-dd').format(todo.expectedCompletionTime)}',
                    style: TextStyle(color: neutralColor6, fontSize: 14),
                  ),
                ],
              ),
            ),

            // ========== 申请说明（优化样式） ==========
            if (_customContent.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  // 改为和申请人信息一致的浅色背景，保持视觉统一
                  color: primaryLightColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  // 移除边框和阴影，和申请人信息卡片保持一致
                  border: Border.all(color: primaryLightColor),
                  boxShadow: null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '申请说明：',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: neutralColor6, // 改为和申请人信息一致的文字颜色
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _customContent,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 开案文件列表
            buildFileList(_applyFiles, '开案文件', context),

            const Divider(height: 1, color: neutralColor2, thickness: 1),
            const SizedBox(height: 20),

            Text('当前负责人', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            _buildResponsibleGroup('software', '软件负责人', groupedResponsibles['software']!),
            const SizedBox(height: 20),
            _buildResponsibleGroup('hardware', '硬件负责人', groupedResponsibles['hardware']!),
            const SizedBox(height: 20),
            _buildResponsibleGroup('test', '测试负责人', groupedResponsibles['test']!),
            const SizedBox(height: 20),

            const Divider(height: 1, color: neutralColor2, thickness: 1),
            const SizedBox(height: 20),

            if (isLeader) ...[
              Text('新增负责人', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              // 替换原普通TextField为Autocomplete搜索下拉框
              Autocomplete<String>(
                onSelected: (String selectedName) {
                  setState(() {
                    _selectedUsername = selectedName;
                    _usernameController.text = selectedName;
                  });
                },
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _allUserList.map((user) => user['username']!);
                  }
                  final String query = textEditingValue.text.toLowerCase();
                  return _allUserList
                      .where((user) => user['username']!.toLowerCase().contains(query))
                      .map((user) => user['username']!);
                },
                fieldViewBuilder: (BuildContext context, TextEditingController fieldController,
                    FocusNode focusNode, VoidCallback onFieldSubmitted) {
                  fieldController.value = _usernameController.value;
                  fieldController.addListener(() {
                    _usernameController.text = fieldController.text;
                  });
                  return TextField(
                    controller: fieldController,
                    focusNode: focusNode,
                    style: const TextStyle(fontSize: 14),
                    enabled: !_isAddingResponsible && !_isLoadingUsers,
                    decoration: InputDecoration(
                      hintText: '输入/选择负责人',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: neutralColor2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: neutralColor2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: primaryColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      prefixIcon: const Icon(Icons.person_outline, color: neutralColor6),
                      suffixIcon: _isLoadingUsers
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
                      )
                          : null,
                    ),
                  );
                },
                optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: MediaQuery.of(context).size.width - 32,
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return ListTile(
                              title: Text(option, style: const TextStyle(fontSize: 14)),
                              onTap: () => onSelected(option),
                              selected: option == _selectedUsername,
                              selectedTileColor: primaryLightColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              // ======================================================
              const SizedBox(height: 16),
              Text('选择负责人角色', style: TextStyle(fontSize: 14, color: neutralColor6, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: DetailResponsibleRole.values.map((role) => ElevatedButton(
                  onPressed: _isAddingResponsible ? null : () => setState(() => _selectedRole = role),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedRole == role ? primaryColor : Colors.white,
                    foregroundColor: _selectedRole == role ? Colors.white : neutralColor6,
                    side: BorderSide(color: _selectedRole == role ? primaryColor : neutralColor2),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: _selectedRole == role ? 2 : 0,
                  ),
                  child: Text(role.chineseName, style: const TextStyle(fontWeight: FontWeight.w500)),
                )).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAddingResponsible ? null : _addtaskPerson,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    shadowColor: primaryColor.withOpacity(0.2),
                  ),
                  child: _isAddingResponsible
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('确认新增负责人', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 构建负责人分组展示
  Widget _buildResponsibleGroup(String groupKey, String groupTitle, List<DetailTaskPerson> responsibles) {
    if (responsibles.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(groupTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: neutralColor2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('暂无', style: TextStyle(fontSize: 14, color: neutralColor6)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(groupTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        Column(
          children: responsibles.map((resp) {
            // 判断编辑权限
            final isLeader = _currentUserTeamRole == '组长';
            final isTestUser = _currentUserRole == 'test';
            final isCurrentUser = resp.userId == _currentUserId;
            final canEditTaskContent = isLeader || isTestUser || isCurrentUser;

            // 判断是否显示重置按钮
            final showResetButton = (isLeader || isTestUser) &&
                resp.personalStatus != 'in_progress' &&
                resp.personalStatus != 'not_started';

            // 确保控制器存在
            if (!_taskContentControllers.containsKey(resp.userId)) {
              _taskContentControllers[resp.userId] = TextEditingController(
                  text: resp.taskContent ?? '暂无任务内容'
              );
              _taskContentLoadingStates[resp.userId] = false;
            }

            // 确保组长布置任务内容控制器存在
            if (!_leaderContentControllers.containsKey(resp.userId)) {
              _leaderContentControllers[resp.userId] = TextEditingController(
                  text: (resp as dynamic).leaderContent ?? '暂无'
              );
              _leaderContentLoadingStates[resp.userId] = false;
              _fileUploadLoadingStates[resp.userId] = false;
              _fileDeleteLoadingStates[resp.userId] = false;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: neutralColor2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 负责人信息行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        resp.username,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: resp.personalStatusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: resp.personalStatusColor.withOpacity(0.3), width: 1),
                        ),
                        child: Text(
                          resp.personalStatusChinese,
                          style: TextStyle(
                            fontSize: 12,
                            color: resp.personalStatusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 时间信息
                  if (resp.startTime != null || resp.completeTime != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: primaryLightColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (resp.startTime != null)
                            Text(
                              '开始时间：${formatTime(resp.startTime!)}',
                              style: TextStyle(fontSize: 12, color: neutralColor6),
                            ),
                          if (resp.completeTime != null)
                            Text(
                              '完成时间：${formatTime(resp.completeTime!)}',
                              style: TextStyle(fontSize: 12, color: neutralColor6),
                            ),
                        ],
                      ),
                    ),

                  // 组长布置的任务内容（仅组长可见可编辑）
                  if (isLeader) ...[
                    const SizedBox(height: 16),
                    Text(
                      '任务：',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: primaryColor),
                    ),
                    const SizedBox(height: 8),
                    // 给TextField添加拖拽监听 + 嵌入保存按钮
                    DragTarget<File>(
                      onAccept: (File file) {
                        // 拖拽文件到编辑框时直接上传
                        _uploadLeaderTaskFile(_currentTodo.id, resp.userId, dragFile: file);
                      },
                      builder: (context, candidateData, rejectedData) {
                        return TextField(
                          controller: _leaderContentControllers[resp.userId],
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: '请输入要布置的任务内容（可拖拽文件到此处直接上传）...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: candidateData.isNotEmpty
                                    ? primaryColor
                                    : neutralColor2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: neutralColor2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: primaryColor, width: 1.5),
                            ),
                            filled: true,
                            fillColor: candidateData.isNotEmpty
                                ? primaryLightColor.withOpacity(0.1)
                                : Colors.white,
                            contentPadding: const EdgeInsets.all(12),
                            // 保存按钮样式
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: _buildSaveButton(
                                isLoading: _leaderContentLoadingStates[resp.userId] == true,
                                onPressed: () => _saveLeaderContent(
                                  _currentTodo.id,
                                  resp.userId,
                                  _leaderContentControllers[resp.userId]!.text.trim(),
                                ),
                              ),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        );
                      },
                    ),
                    // 传递userId给buildFileList，用于删除功能
                    buildFileList(resp.leaderfiles, '任务文件', context, userId: resp.userId),
                    // 选择文件上传按钮
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _fileUploadLoadingStates[resp.userId] == true
                            ? null
                            : () => _uploadLeaderTaskFile(_currentTodo.id, resp.userId),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: primaryColor, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: primaryLightColor.withOpacity(0.1),
                        ),
                        child: _fileUploadLoadingStates[resp.userId] == true
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: primaryColor,
                            strokeWidth: 2,
                          ),
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.upload_file, color: primaryColor, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '选择任务文件上传',
                              style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ]
                  // 非组长用户仅查看组长布置的任务内容
                  else if (resp.leaderContent != null && resp.leaderContent != '暂无') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryLightColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '组长布置的任务：',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            resp.leaderContent ?? '暂无',
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    // 展示组长上传的文件（非组长用户也能看，但不能删除）
                    buildFileList(resp.leaderfiles, '组长上传文件', context),
                    const SizedBox(height: 16),
                  ],

                  // 任务内容编辑框
                  const SizedBox(height: 16),
                  Text(
                    '负责人工作内容：',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _taskContentControllers[resp.userId],
                    maxLines: 4,
                    enabled: canEditTaskContent,
                    decoration: InputDecoration(
                      hintText: '暂无...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: neutralColor2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: neutralColor2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: primaryColor, width: 1.5),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: neutralColor2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(12),
                      // 保存按钮样式
                      suffixIcon: canEditTaskContent
                          ? Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: _buildSaveButton(
                          isLoading: _taskContentLoadingStates[resp.userId] == true,
                          onPressed: () => _saveTaskContent(
                            _currentTodo.id,
                            resp.userId,
                            _taskContentControllers[resp.userId]!.text.trim(),
                          ),
                        ),
                      )
                          : null,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 负责人上传文件列表（只显示files，不显示leaderfiles）
                  buildFileList(resp.files, '负责人上传文件', context),

                  // 操作按钮行
                  if (showResetButton)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () => _resetToInProgress(resp.userId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: warningColor.withOpacity(0.9),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: const Text('重置为进行中', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}