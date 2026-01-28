import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'apply_model.dart';
import 'apply_detail_api_service.dart';
import 'package:workflow/constants/api_constants.dart';
import 'apply_responsible_detail.dart';

// 自定义可自选复制的文本组件（修复 overflow 兼容性问题）
class CopyableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool enableInteractiveSelection;

  const CopyableText(
      this.text, {
        super.key,
        this.style,
        this.textAlign,
        this.maxLines,
        this.enableInteractiveSelection = true,
      });

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      enableInteractiveSelection: enableInteractiveSelection,
      // 自定义选择菜单样式
      toolbarOptions: const ToolbarOptions(
        copy: true,
        selectAll: true,
        cut: false,
        paste: false,
      ),
      // 处理超长文本的显示（替代 overflow: ellipsis 的效果）
      minLines: 1,
    );
  }
}

class ApplyDetailPage extends StatefulWidget {
  final ApplyModel applyModel;

  const ApplyDetailPage({super.key, required this.applyModel});

  @override
  State<ApplyDetailPage> createState() => _ApplyDetailPageState();
}

class _ApplyDetailPageState extends State<ApplyDetailPage> {
  bool _isLeader = false;
  bool _isLoading = false;
  bool _isTestRole = false;
  bool _needRefreshList = false;
  String? _currentUserId;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _initUserInfo();
    _fetchApplyDetail();
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
    setState(() => _isTestRole = isTest);
  }

  // 从后端获取最新的任务详情
  Future<void> _fetchApplyDetail() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic>? data = await ApplyDetailApiService.fetchApplyDetail(widget.applyModel.id);
      if (data != null) {
        setState(() {
          // 更新本地模型数据
          if (data['responsibles'] != null && data['responsibles'] is List) {
            widget.applyModel.responsibleDetails = (data['responsibles'] as List)
                .map((item) => ResponsibleDetailModel.fromJson(item))
                .toList();
          }
          // 更新开案文件数据
          if (data['applyFiles'] != null && data['applyFiles'] is List) {
            widget.applyModel.applyFiles = (data['applyFiles'] as List)
                .map((item) => FileModel.fromJson(item))
                .toList();
          }
        });
      }
    } catch (e) {
      dev.log('获取任务详情失败: $e');
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
              child: CopyableText(
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

  // 通用信息行组件
  Widget _buildInfoRow(String label, String value, {bool isDetail = false}) {
    List<String> timeLabels = ['申请时间', '预计完成时间', '开始时间', '完成时间'];
    String displayValue = value;

    if (timeLabels.contains(label) && value.isNotEmpty && value != '未开始' && value != '未完成') {
      displayValue = formatTime(value);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isDetail ? 80 : 100,
            child: CopyableText(
              '$label：',
              style: TextStyle(
                fontSize: isDetail ? 13 : 14,
                color: const Color(0xFF86909C),
              ),
            ),
          ),
          Expanded(
            child: CopyableText(
              displayValue.isEmpty ? '无' : displayValue,
              style: TextStyle(
                fontSize: isDetail ? 13 : 14,
                color: const Color(0xFF4E5969),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建开案文件列表项
  Widget _buildApplyFileItem(FileModel file) {
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

    // 处理超长文件名（截断后显示）
    String getDisplayFileName() {
      if (decodedFileName.length > 20) {
        return '${decodedFileName.substring(0, 20)}...';
      }
      return decodedFileName;
    }

    // 打开文件方法
    void openFile() async {
      try {
        String fullFileUrl = '$baseUrl${file.fileUrl}';

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
                              CopyableText(
                                decodedFileName,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              CopyableText(
                                '${_formatFileSize(file.fileSize)} | ${formatTime(file.uploadTime)}',
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: openFile,
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
                  CopyableText(
                    getDisplayFileName(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      CopyableText(
                        formatTime(file.uploadTime),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF86909C)),
                      ),
                      const SizedBox(width: 8),
                      CopyableText(
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

  // 构建角色分组卡片（方块）
  Widget _buildRoleGroupCard({
    required String title,
    required List<ResponsibleDetailModel> responsibles,
  }) {
    if (responsibles.isEmpty) return const SizedBox.shrink();

    // 构建单个负责人摘要卡片
    Widget buildResponsibleCard(ResponsibleDetailModel detail) {
      // 处理超长任务内容
      String getDisplayContent() {
        if (detail.leaderContent.isEmpty) return '暂无任务';
        if (detail.leaderContent.length > 40) {
          return '${detail.leaderContent.substring(0, 40)}...';
        }
        return detail.leaderContent;
      }

      return InkWell(
        onTap: () async {
          // 跳转到详情页面
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ApplyResponsibleDetailPage(
                applyModel: widget.applyModel,
                detail: detail,
              ),
            ),
          );

          // 刷新数据
          if (result == 'need_refresh') {
            setState(() => _needRefreshList = true);
            _fetchApplyDetail();
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E6EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CopyableText(
                    detail.username,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4E5969),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: detail.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: detail.statusColor, width: 1),
                    ),
                    child: CopyableText(
                      detail.personalStatusCn,
                      style: TextStyle(
                        fontSize: 12,
                        color: detail.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              CopyableText(
                '任务：${getDisplayContent()}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4E5969),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  CopyableText(
                    '开始：${detail.startTime ?? '未开始'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF86909C),
                    ),
                  ),
                  const SizedBox(width: 16),
                  CopyableText(
                    '完成：${detail.completeTime ?? '未完成'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF86909C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: CopyableText(
                  '查看详情 >',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF0088FF),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E6EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CopyableText(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF001529),
            ),
          ),
          const SizedBox(height: 12),
          ...responsibles.map((detail) => buildResponsibleCard(detail)).toList(),
        ],
      ),
    );
  }

  // 组长更新整体任务状态
  Future<void> _updateOverallStatus(String newStatus) async {
    if (!_isLeader) {
      _showSnackBar('仅组长可更新整体任务状态', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> data = await ApplyDetailApiService.updateOverallStatus(
        widget.applyModel.id,
        newStatus,
      );

      if (data['success']) {
        _showSnackBar('整体任务状态更新成功');
        _fetchApplyDetail();
      } else {
        _showSnackBar(data['msg'] ?? '更新失败', isError: true);
      }
    } catch (e) {
      _showSnackBar('网络错误: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const CopyableText('任务详情'),
          backgroundColor: const Color(0xFF0088FF),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF0088FF))),
      );
    }

    ApplyModel apply = widget.applyModel;
    String overdueText = apply.overdueDays > 0 ? '（逾期${apply.overdueDays}天）' : '';
    String progressText = '${(apply.completionProgress * 100).toStringAsFixed(0)}%';

    return Scaffold(
      appBar: AppBar(
        title: const CopyableText('任务详情'),
        backgroundColor: const Color(0xFF0088FF),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _needRefreshList ? 'need_refresh' : null);
          },
        ),
        actions: [
          // 组长显示整体状态修改按钮
          if (_isLeader)
            PopupMenuButton<String>(
              onSelected: _updateOverallStatus,
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'not_started', child: CopyableText('未开始')),
                const PopupMenuItem(value: 'in_progress', child: CopyableText('进行中')),
                const PopupMenuItem(value: 'paused', child: CopyableText('已暂停')),
                const PopupMenuItem(value: 'completed', child: CopyableText('已完成')),
                const PopupMenuItem(value: 'overdue', child: CopyableText('已逾期')),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.settings),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：客户+状态
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: apply.overallStatus == 'overdue'
                    ? apply.overallStatusColor.withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: apply.overallStatus == 'overdue'
                      ? apply.overallStatusColor
                      : const Color(0xFFE5E6EB),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CopyableText(
                    apply.customer,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF001529),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: apply.overallStatusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: apply.overallStatusColor, width: 1),
                        ),
                        child: CopyableText(
                          '${apply.overallStatusCn}$overdueText',
                          style: TextStyle(
                            color: apply.overallStatusColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      CopyableText(
                        '完成进度：$progressText',
                        style: TextStyle(
                          fontSize: 14,
                          color: apply.completionProgress == 1.0
                              ? Colors.green
                              : apply.completionProgress > 0
                              ? Colors.blue
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: apply.completionProgress,
                    backgroundColor: const Color(0xFFE5E6EB),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      apply.completionProgress == 1.0
                          ? Colors.green
                          : apply.completionProgress > 0
                          ? Colors.blue
                          : Colors.grey,
                    ),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // 基础信息方块
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
                  const CopyableText(
                    '基础信息',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF001529),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('业务名称', apply.business),
                  _buildInfoRow('申请人', apply.applicant),
                  _buildInfoRow('申请时间', apply.applyTime),
                  _buildInfoRow('预计完成时间', apply.expectedCompletionTime),
                  _buildInfoRow('自定义内容', apply.customContent),

                  // 开案文件
                  const SizedBox(height: 4),
                  if (apply.applyFiles.isNotEmpty) ...[
                    ...apply.applyFiles.map((file) => _buildApplyFileItem(file)).toList(),
                  ] else ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 1),
                      child: CopyableText(
                        '暂无开案文件',
                        style: TextStyle(fontSize: 14, color: Color(0xFF86909C)),
                      ),
                    ),
                  ],

                  // 负责人汇总
                  const SizedBox(height: 12),
                  _buildInfoRow('硬件负责人', apply.hardwareHandlers.join('、')),
                  _buildInfoRow('软件负责人', apply.softwareHandlers.join('、')),
                  _buildInfoRow('测试负责人', apply.testHandlers.join('、')),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 硬件负责人方块
            _buildRoleGroupCard(
              title: '硬件负责人',
              responsibles: apply.responsibleDetails.where((d) => d.role == 'hardware').toList(),
            ),

            // 软件负责人方块
            _buildRoleGroupCard(
              title: '软件负责人',
              responsibles: apply.responsibleDetails.where((d) => d.role == 'software').toList(),
            ),

            // 测试负责人方块
            _buildRoleGroupCard(
              title: '测试负责人',
              responsibles: apply.responsibleDetails.where((d) => d.role == 'test').toList(),
            ),
          ],
        ),
      ),
    );
  }
}