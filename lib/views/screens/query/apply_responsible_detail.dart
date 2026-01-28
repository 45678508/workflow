import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:developer' as dev;
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'apply_model.dart';
import 'apply_detail_api_service.dart';
import 'package:workflow/constants/api_constants.dart';

class ApplyResponsibleDetailPage extends StatefulWidget {
  final ApplyModel applyModel;
  final ResponsibleDetailModel detail;

  const ApplyResponsibleDetailPage({
    super.key,
    required this.applyModel,
    required this.detail,
  });

  @override
  State<ApplyResponsibleDetailPage> createState() => _ApplyResponsibleDetailPageState();
}

class _ApplyResponsibleDetailPageState extends State<ApplyResponsibleDetailPage> {
  bool _isLoading = false;
  bool _isLeader = false;
  bool _isTestRole = false;
  bool _isUploading = false;
  bool _needRefresh = false;
  String? _currentUserId;
  String? _currentUserRole;
  late TextEditingController _taskContentController;
  late TextEditingController _testFeedbackController;
  bool _canEdit = true;
  List<Map<String, dynamic>> _taskHistory = [];

  @override
  void initState() {
    super.initState();
    _taskContentController = TextEditingController(text: widget.detail.taskContent);
    _testFeedbackController = TextEditingController(
      text: widget.detail.testFeedback?.content ?? '',
    );
    _initUserInfo();
    _initTaskContentHistory();
  }

  @override
  void dispose() {
    _taskContentController.dispose();
    _testFeedbackController.dispose();
    super.dispose();
  }

  // 初始化用户信息和权限
  Future<void> _initUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('userId');
      _currentUserRole = prefs.getString('teamRole') ?? '';
      _isLeader = _currentUserRole == '组长' || _currentUserRole == 'admin';
    });

    // 获取测试角色权限
    bool isTest = await ApplyDetailApiService.getTestRolePermission(widget.applyModel.id);
    setState(() {
      _isTestRole = isTest;
    });
  }

  // 初始化任务内容历史记录
  Future<void> _initTaskContentHistory() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> result = await ApplyDetailApiService.getTaskContentHistory(
        widget.applyModel.id,
        widget.detail.userId,
      );

      if (result['success'] == true) {
        setState(() {
          _canEdit = result['data']['canEdit'] ?? false;
          _taskHistory = List<Map<String, dynamic>>.from(result['data']['history'] ?? []);
        });
      } else {
        setState(() {
          _canEdit = result['data']['canEdit'] ?? true;
          _taskHistory = result['data']['history'] ?? [];
        });
      }
    } catch (e) {
      dev.log('获取任务内容历史失败: $e');
      setState(() {
        _canEdit = true;
        _taskHistory = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 检查是否有编辑权限
  bool _hasEditPermission() {
    if (_isLeader || _isTestRole) return true;
    return widget.detail.userId == _currentUserId;
  }

  // 显示提示消息
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 3 : 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // 保存任务内容
  Future<void> _saveTaskContent() async {
    String content = _taskContentController.text.trim();
    if (content.isEmpty) {
      _showSnackBar('任务内容不能为空', isError: true);
      return;
    }

    if (!_canEdit) {
      _showSnackBar('该内容已锁定，无法编辑', isError: true);
      return;
    }

    bool? shouldCreateRecord = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存确认'),
        content: const Text('是否生成今日的记录？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('仅保存'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (shouldCreateRecord == null) return;

    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> result = await ApplyDetailApiService.saveTaskContent(
        widget.applyModel.id,
        widget.detail.userId,
        content,
        shouldCreateRecord: shouldCreateRecord,
      );

      if (result['success'] == true) {
        _showSnackBar(shouldCreateRecord
            ? '任务内容保存成功并生成今日记录'
            : '任务内容保存成功');
        setState(() {
          _needRefresh = true;
          widget.detail.taskContent = content;
        });
        _initTaskContentHistory();
      } else {
        _showSnackBar(result['msg'] ?? '保存失败', isError: true);
        if (result['msg']?.contains('已过编辑时间') == true) {
          setState(() => _canEdit = false);
        }
      }
    } catch (e) {
      dev.log('保存任务内容异常: $e');
      _showSnackBar('保存失败: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 保存测试反馈
  Future<void> _saveTestFeedback() async {
    String content = _testFeedbackController.text.trim();
    if (content.isEmpty) {
      _showSnackBar('测试反馈内容不能为空', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> result = await ApplyDetailApiService.saveTestFeedback(
        widget.applyModel.id,
        widget.detail.userId,
        content,
      );

      if (result['success'] == true) {
        _showSnackBar('测试反馈保存成功');
        setState(() {
          _needRefresh = true;
          widget.detail.testFeedback = TestFeedbackModel(
            content: content,
            creatorId: _currentUserId ?? '', // 🔴 增加空值保护
            creatorName: '当前用户',
            createTime: DateTime.now().toIso8601String(),
            isEditable: true, // 🔴 添加必填的 isEditable 参数
          );
        });
      } else {
        _showSnackBar(result['msg'] ?? '保存失败', isError: true);
      }
    } catch (e) {
      dev.log('保存测试反馈异常: $e');
      _showSnackBar('保存失败: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 更新个人任务状态
  Future<void> _updatePersonalStatus(String newStatus) async {
    if (widget.detail.personalStatus == 'completed' || _isLoading) return;

    if (newStatus == 'completed') {
      String content = _taskContentController.text.trim();
      if (content.isEmpty) {
        _showSnackBar('请填写任务内容', isError: true);
        return;
      }
      await _saveTaskContent();
    }

    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> data = await ApplyDetailApiService.updatePersonalStatus(
        widget.applyModel.id,
        widget.detail.userId,
        newStatus,
      );

      if (data['success']) {
        _showSnackBar('任务状态更新成功');
        setState(() {
          widget.detail.personalStatus = newStatus;
          if (newStatus == 'completed') {
            widget.detail.completeTime = DateTime.now().toIso8601String();
          }
          _needRefresh = true;
        });

        if (newStatus == 'completed') {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pop(context, _needRefresh ? 'need_refresh' : null);
            }
          });
        }
      } else {
        _showSnackBar(data['msg'] ?? '更新失败', isError: true);
      }
    } catch (e) {
      _showSnackBar('网络错误: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 测试不合格 - 重置任务状态
  Future<void> _onTestUnqualified() async {
    if (_isLoading) return;

    if (!_isTestRole && !_isLeader) {
      _showSnackBar('仅测试负责人或组长可执行此操作', isError: true);
      return;
    }

    if (_isTestRole && widget.detail.userId == _currentUserId) {
      _showSnackBar('测试负责人仅可重置他人任务状态', isError: true);
      return;
    }

    TextEditingController reasonController = TextEditingController();
    String? rejectReason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('测试不合格'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              hintText: '请输入打回原因',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
            onChanged: (value) => setState(() {}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: reasonController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, reasonController.text.trim()),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );

    if (rejectReason == null || rejectReason.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> result = await ApplyDetailApiService.resetResponsibleStatus(
        widget.applyModel.id,
        widget.detail.userId,
        rejectReason,
      );

      if (result['success'] == true) {
        _showSnackBar('已重置为进行中并记录打回原因');
        setState(() {
          widget.detail.personalStatus = 'in_progress';
          widget.detail.rejectRecords.add(RejectRecordModel(
            rejectorName: '当前用户',
            rejectTime: DateTime.now().toIso8601String(),
            reason: rejectReason,
          ));
          _needRefresh = true;
        });
      } else {
        _showSnackBar(result['msg'] ?? '重置失败', isError: true);
      }
    } catch (e) {
      _showSnackBar('重置失败: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 上传文件
  Future<void> _uploadFile() async {
    bool isCurrentUser = widget.detail.userId == _currentUserId;
    if (!isCurrentUser && !_isTestRole && !_isLeader) {
      _showSnackBar('仅负责人、测试或组长可上传文件', isError: true);
      return;
    }

    if (widget.detail.personalStatus == 'completed') {
      _showSnackBar('任务已完成，无法上传文件', isError: true);
      return;
    }

    if (_isUploading) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null) return;

      setState(() => _isUploading = true);

      Map<String, dynamic> uploadResult = await ApplyDetailApiService.uploadTaskFile(
        widget.applyModel.id,
        widget.detail.userId,
        result,
      );

      if (uploadResult['success'] == true) {
        setState(() {
          FileModel newFile = FileModel(
            fileName: uploadResult['data']['fileName'],
            fileType: uploadResult['data']['fileType'],
            fileSize: uploadResult['data']['fileSize'] ?? 0,
            fileUrl: uploadResult['data']['fileUrl'],
            uploadTime: uploadResult['data']['uploadTime'],
          );
          widget.detail.files.add(newFile);
          _needRefresh = true;
        });
        _showSnackBar('文件上传成功');
      } else {
        _showSnackBar(uploadResult['msg'] ?? '上传失败', isError: true);
      }
    } catch (e) {
      dev.log('文件上传异常：$e');
      _showSnackBar('文件上传失败: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // 删除文件
  Future<void> _deleteFile(FileModel file) async {
    bool isCurrentUser = widget.detail.userId == _currentUserId;
    if (!isCurrentUser && !_isTestRole && !_isLeader) {
      _showSnackBar('仅负责人、测试或组长可删除文件', isError: true);
      return;
    }

    if (widget.detail.personalStatus == 'completed') {
      _showSnackBar('任务已完成，无法删除文件', isError: true);
      return;
    }

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除该文件吗？此操作不可恢复'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> result = await ApplyDetailApiService.deleteTaskFile(
        widget.applyModel.id,
        widget.detail.userId,
        file.fileUrl,
      );

      if (result['success']) {
        _showSnackBar('文件删除成功');
        setState(() {
          widget.detail.files.removeWhere((f) => f.fileUrl == file.fileUrl);
          _needRefresh = true;
        });
      } else {
        _showSnackBar(result['msg'] ?? '删除失败', isError: true);
      }
    } catch (e) {
      _showSnackBar('网络错误: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 格式化文件大小
  String _formatFileSize(int size) {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // 格式化时间
  String _formatTime(String timeStr) {
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

  // 打开文件
  Future<void> _openFile(FileModel file) async {
    try {
      String fullFileUrl = '$baseUrl${file.fileUrl}';
      dev.log('文件预览地址: $fullFileUrl');

      if (file.fileType.startsWith('image/')) {
        await showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.black,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InteractiveViewer(
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Image.network(
                    fullFileUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white, size: 64),
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
                              '${_formatFileSize(file.fileSize)} | ${_formatTime(file.uploadTime)}',
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
      } else if (file.fileType == 'application/pdf') {
        await OpenFile.open(fullFileUrl);
      } else {
        final result = await OpenFile.open(fullFileUrl);
        if (result.type != ResultType.done) {
          _showSnackBar('无法打开文件: ${result.message}', isError: true);
        }
      }
    } catch (e) {
      dev.log('打开文件失败: $e');
      _showSnackBar('无法打开文件，请检查文件是否存在或格式是否支持', isError: true);
    }
  }

  // 构建文件列表项
  Widget _buildFileItem(FileModel file) {
    IconData fileIcon = Icons.insert_drive_file;
    Color iconColor = Colors.grey;

    if (file.fileType.startsWith('image/')) {
      fileIcon = Icons.image;
      iconColor = Colors.pinkAccent;
    } else if (file.fileType.contains('pdf')) {
      fileIcon = Icons.picture_as_pdf;
      iconColor = Colors.redAccent;
    } else if (file.fileType.contains('excel') || file.fileName.endsWith('.xlsx') || file.fileName.endsWith('.xls')) {
      fileIcon = Icons.table_chart;
      iconColor = Colors.greenAccent;
    } else if (file.fileType.contains('word') || file.fileName.endsWith('.docx') || file.fileName.endsWith('.doc')) {
      fileIcon = Icons.description;
      iconColor = Colors.blueAccent;
    } else if (file.fileType.contains('zip') || file.fileType.contains('rar')) {
      fileIcon = Icons.archive;
      iconColor = Colors.orangeAccent;
    }

    String decodedFileName;
    try {
      decodedFileName = file.fileName;
    } catch (e) {
      decodedFileName = file.fileName;
      dev.log('文件名解码失败: $e');
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
        onTap: () => _openFile(file),
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            file.fileType.startsWith('image/')
                ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                Uri.encodeFull('$baseUrl${file.fileUrl}'),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    decodedFileName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _formatTime(file.uploadTime),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF86909C)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatFileSize(file.fileSize),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF86909C)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
              onPressed: _isLoading || widget.detail.personalStatus == 'completed'
                  ? null
                  : () => _deleteFile(file),
              tooltip: '删除文件',
            ),
          ],
        ),
      ),
    );
  }

  // 构建组长文件列表项
  Widget _buildLeaderFileItem(FileModel file) {
    IconData fileIcon = Icons.insert_drive_file;
    Color iconColor = Colors.grey;

    if (file.fileType.startsWith('image/')) {
      fileIcon = Icons.image;
      iconColor = Colors.pinkAccent;
    } else if (file.fileType.contains('pdf')) {
      fileIcon = Icons.picture_as_pdf;
      iconColor = Colors.redAccent;
    } else if (file.fileType.contains('excel') || file.fileName.endsWith('.xlsx') || file.fileName.endsWith('.xls')) {
      fileIcon = Icons.table_chart;
      iconColor = Colors.greenAccent;
    } else if (file.fileType.contains('word') || file.fileName.endsWith('.docx') || file.fileName.endsWith('.doc')) {
      fileIcon = Icons.description;
      iconColor = Colors.blueAccent;
    } else if (file.fileType.contains('zip') || file.fileType.contains('rar')) {
      fileIcon = Icons.archive;
      iconColor = Colors.orangeAccent;
    }

    String decodedFileName;
    try {
      decodedFileName = file.fileName;
    } catch (e) {
      decodedFileName = file.fileName;
      dev.log('文件名解码失败: $e');
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
        onTap: () => _openFile(file),
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            file.fileType.startsWith('image/')
                ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                Uri.encodeFull('$baseUrl${file.fileUrl}'),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    decodedFileName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _formatTime(file.uploadTime),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF86909C)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatFileSize(file.fileSize),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF86909C)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.detail.roleCn} - ${widget.detail.username}'),
          backgroundColor: const Color(0xFF0088FF),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF0088FF))),
      );
    }

    bool isCurrentUser = widget.detail.userId == _currentUserId;
    bool canOperateStatus = isCurrentUser && widget.detail.personalStatus != 'completed';
    bool canEditContent = _hasEditPermission() && widget.detail.personalStatus != 'completed';
    bool canRejectTask = (_isTestRole || _isLeader) && !isCurrentUser && widget.detail.personalStatus == 'completed';
    bool canUploadFile = (isCurrentUser || _isTestRole || _isLeader) && widget.detail.personalStatus != 'completed';

    // 测试反馈编辑权限
    bool canEditTestFeedback = false;
    if (_isTestRole || _isLeader) {
      if (widget.detail.testFeedback == null) {
        canEditTestFeedback = true;
      } else {
        canEditTestFeedback = widget.detail.testFeedback?.creatorId == _currentUserId && widget.detail.personalStatus != 'completed';
      }
    }

    // 测试人员自己的卡片判断
    bool isTestSelfCard = _isTestRole && widget.detail.userId == _currentUserId;
    bool hasTestFeedbackContent = (widget.detail.testFeedback?.content?.isNotEmpty ?? false);
    bool canShowTestFeedbackArea = !isTestSelfCard && hasTestFeedbackContent;

    // 测试人员完成按钮禁用判断
    bool disableTestComplete = false;
    if (_isTestRole && widget.detail.userId == _currentUserId) {
      disableTestComplete = widget.applyModel.responsibleDetails.every((r) =>
      r.userId != _currentUserId && r.personalStatus == 'completed');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.detail.roleCn} - ${widget.detail.username}'),
        backgroundColor: const Color(0xFF0088FF),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _needRefresh ? 'need_refresh' : null);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部信息
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E6EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.detail.username,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF001529),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.detail.statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: widget.detail.statusColor, width: 1),
                        ),
                        child: Text(
                          widget.detail.personalStatusCn,
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.detail.statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '角色：${widget.detail.roleCn}',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF4E5969)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '开始时间：${widget.detail.startTime ?? '未开始'}',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF4E5969)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '完成时间：${widget.detail.completeTime ?? '未完成'}',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF4E5969)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 组长任务内容
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E6EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '分配任务',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF001529),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Text(
                      widget.detail.leaderContent.isEmpty ? '暂无任务内容' : widget.detail.leaderContent,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4E5969),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),
                  if (widget.detail.leaderfiles.isNotEmpty) ...[
                    ...widget.detail.leaderfiles.map((file) => _buildLeaderFileItem(file)).toList(),
                  ] else ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '暂无任务文件',
                        style: TextStyle(fontSize: 14, color: Color(0xFF86909C)),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 完成内容编辑
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E6EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '完成内容',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF001529),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_canEdit && canEditContent)
                    TextField(
                      controller: _taskContentController,
                      maxLines: 5,
                      enabled: true,
                      decoration: InputDecoration(
                        hintText: '请输入任务完成内容...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFF0088FF)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(10),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.save, size: 18, color: Color(0xFF0088FF)),
                          onPressed: _isLoading ? null : _saveTaskContent,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4E5969),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _taskContentController.text.trim().isEmpty ? '暂无完成内容' : _taskContentController.text.trim(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4E5969),
                            ),
                          ),
                          if (_canEdit == false)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '该内容已锁定（仅可编辑当天修改的内容）',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // 编辑历史
                  if (_taskHistory.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '编辑历史',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF86909C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._taskHistory.map((history) => Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${history['editorName']} | ${history['editTime']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF86909C),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            history['content'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4E5969),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 上传文件区域
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E6EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '上传文件',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF001529),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (canUploadFile)
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : _uploadFile,
                      icon: _isUploading
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Icon(Icons.upload_file, size: 18),
                      label: const Text('选择文件上传'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0088FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  if (!canUploadFile && widget.detail.personalStatus == 'completed')
                    const Text(
                      '任务已完成，无法上传文件',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF86909C),
                      ),
                    ),
                  if (!canUploadFile && widget.detail.personalStatus != 'completed' && !isCurrentUser && !_isTestRole && !_isLeader)
                    const Text(
                      '仅负责人、测试或组长可上传文件',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF86909C),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (widget.detail.files.isNotEmpty) ...[
                    ...widget.detail.files.map((file) => _buildFileItem(file)).toList(),
                  ] else ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '暂无上传文件',
                        style: TextStyle(fontSize: 14, color: Color(0xFF86909C)),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 测试反馈区域
            if (!isTestSelfCard) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E6EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '测试反馈',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF001529),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (canEditTestFeedback)
                      Column(
                        children: [
                          TextField(
                            controller: _testFeedbackController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: '请输入测试反馈内容...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: Color(0xFF0088FF)),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.all(10),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4E5969),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveTestFeedback,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0088FF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text('保存反馈'),
                            ),
                          ),
                        ],
                      )
                    else if (canShowTestFeedbackArea)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.detail.testFeedback?.content ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF4E5969),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '反馈人：${widget.detail.testFeedback?.creatorName ?? '未知'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF86909C),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '反馈时间：${_formatTime(widget.detail.testFeedback?.createTime ?? '')}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF86909C),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Text(
                        '暂无测试反馈',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF86909C),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // 打回记录
            if (widget.detail.rejectRecords.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E6EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '打回记录',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF001529),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...widget.detail.rejectRecords.map((record) => Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.reason,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4E5969),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '打回人：${record.rejectorName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF86909C),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '打回时间：${_formatTime(record.rejectTime)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF86909C),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 操作按钮区域
            if (canOperateStatus || canRejectTask)
              Row(
                children: [
                  if (canOperateStatus)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading || (isTestSelfCard && disableTestComplete)
                            ? null
                            : () => _updatePersonalStatus('completed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0088FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text('标记为已完成'),
                      ),
                    ),
                  if (canOperateStatus && canRejectTask) const SizedBox(width: 12),
                  if (canRejectTask)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onTestUnqualified,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text('测试不合格'),
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}