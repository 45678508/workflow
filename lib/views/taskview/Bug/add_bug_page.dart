import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workflow/constants/api_constants.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// BUG数据模型
class BugFormData {
  String bugNo;
  String problemDesc;
  String createTime;
  String moduleType;
  String reproduceProb;
  String severity;
  String foundVersion;
  String analysis;
  String reviewResult;
  String remark;

  BugFormData({
    this.bugNo = '',
    this.problemDesc = '',
    String? createTime,
    this.moduleType = '固件',
    this.reproduceProb = '必现',
    this.severity = '中等',
    this.foundVersion = '',
    this.analysis = '',
    this.reviewResult = '无',
    this.remark = '',
  }) : createTime = createTime ?? DateFormat('yyyy/MM/dd').format(DateTime.now());

  // 转换为提交用的Map
  Map<String, dynamic> toJson() {
    return {
      'bugNo': bugNo,
      'problemDesc': problemDesc,
      'createTime': createTime,
      'moduleType': moduleType,
      'reproduceProb': reproduceProb,
      'severity': severity,
      'foundVersion': foundVersion,
      'analysis': analysis,
      'reviewResult': reviewResult,
      'remark': remark,
    };
  }

  // 验证当前BUG数据是否完整
  bool validate() {
    return bugNo.isNotEmpty &&
        problemDesc.isNotEmpty &&
        foundVersion.isNotEmpty &&
        analysis.isNotEmpty;
  }

  // 获取验证错误信息
  String? getValidationError() {
    if (bugNo.isEmpty) return 'BUG编号不能为空';
    if (problemDesc.isEmpty) return '问题描述不能为空';
    if (foundVersion.isEmpty) return '发现版本不能为空';
    if (analysis.isEmpty) return '问题分析不能为空';
    return null;
  }
}

// 固定选项的下拉组件（不可编辑）
class FixedDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const FixedDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(isDense: true),
      items: options
          .map((option) => DropdownMenuItem(
        value: option,
        child: Text(option),
      ))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
      isExpanded: true,
    );
  }
}

// 可编辑的下拉选择组件
class EditableDropdown extends StatefulWidget {
  final String initialValue;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String hintText;

  const EditableDropdown({
    super.key,
    required this.initialValue,
    required this.options,
    required this.onChanged,
    this.hintText = '',
  });

  @override
  State<EditableDropdown> createState() => _EditableDropdownState();
}

class _EditableDropdownState extends State<EditableDropdown> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant EditableDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hintText,
        suffixIcon: PopupMenuButton<String>(
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          onSelected: (value) {
            setState(() {
              _controller.text = value;
            });
            widget.onChanged(value);
          },
          itemBuilder: (context) => widget.options
              .map((option) => PopupMenuItem(
            value: option,
            child: Text(option),
          ))
              .toList(),
        ),
      ),
      onChanged: (value) {
        widget.onChanged(value ?? '');
      },
    );
  }
}

// 独立的表格式添加BUG页面（修复界面显示和提交问题）
class AddBugPage extends StatefulWidget {
  final String userId;
  final VoidCallback onSubmitSuccess;

  const AddBugPage({
    super.key,
    required this.userId,
    required this.onSubmitSuccess,
  });

  @override
  State<AddBugPage> createState() => _AddBugPageState();
}

class _AddBugPageState extends State<AddBugPage> {
  final List<BugFormData> _bugFormList = [];
  final DateFormat _dateFormatter = DateFormat('yyyy/MM/dd');
  bool _isSubmitting = false;
  String _currentUsername = ''; // 存储当前登录用户名

  // 优化单元格宽度，适配所有屏幕（更紧凑的宽度计算）
  double getCellWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // 按屏幕宽度动态计算，确保靠左显示且完整
    if (screenWidth > 1200) return 110;
    if (screenWidth > 800) return 90;
    return 70;
  }

  double getWideCellWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 150;
    if (screenWidth > 800) return 130;
    return 110;
  }

  @override
  void initState() {
    super.initState();
    _bugFormList.add(BugFormData());
    _getCurrentUsername();
  }

  // 从SharedPreferences获取当前用户名
  Future<void> _getCurrentUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');
    setState(() {
      _currentUsername = username ?? '未知用户';
    });
  }

  // 添加新的BUG表单
  void _addNewBugForm() {
    setState(() {
      _bugFormList.add(BugFormData());
    });
  }

  // 删除指定索引的BUG表单
  void _removeBugForm(int index) {
    if (_bugFormList.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少需要保留一条BUG数据')),
      );
      return;
    }
    setState(() {
      _bugFormList.removeAt(index);
    });
  }

  // 选择日期
  Future<void> _selectDate(int index) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _bugFormList[index].createTime = _dateFormatter.format(picked);
      });
    }
  }

  // 批量提交BUG（优化错误处理）
  Future<void> _submitBugs() async {
    // 先验证所有表单
    for (var i = 0; i < _bugFormList.length; i++) {
      final error = _bugFormList[i].getValidationError();
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('第${i + 1}条BUG：$error')),
        );
        return;
      }
    }

    if (_isSubmitting) return;

    try {
      setState(() {
        _isSubmitting = true;
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // 批量提交（逐条提交）
      int successCount = 0;
      List<String> errorMessages = [];

      for (var i = 0; i < _bugFormList.length; i++) {
        final bugData = _bugFormList[i].toJson();
        try {
          final response = await http.post(
            Uri.parse('$baseUrl/api/bug'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(bugData),
          );

          if (response.statusCode == 201) {
            successCount++;
          } else {
            try {
              final jsonData = json.decode(response.body);
              errorMessages.add('第${i + 1}条：${jsonData['message'] ?? '提交失败'}');
            } catch (e) {
              errorMessages.add('第${i + 1}条：服务器返回错误 - ${response.statusCode}');
            }
          }
        } catch (e) {
          errorMessages.add('第${i + 1}条：网络错误 - $e');
        }
      }

      // 显示提交结果
      if (errorMessages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功提交$successCount条BUG数据')),
        );
        widget.onSubmitSuccess();
        if (mounted) Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SingleChildScrollView(
              child: Text('提交结果：成功$successCount条，失败${errorMessages.length}条\n${errorMessages.join('\n')}'),
            ),
            duration: const Duration(seconds: 10),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('批量提交BUG失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('批量提交失败，请稍后重试')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cellWidth = getCellWidth(context);
    final wideCellWidth = getWideCellWidth(context);
    final narrowCellWidth = 70.0;

    // 重新计算表格总宽度（移除完成时间和责任人列后）
    final totalTableWidth = 8 * cellWidth + 2 * wideCellWidth + narrowCellWidth + 20;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('批量添加BUG'),
        backgroundColor: const Color(0xFF1890FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 操作按钮区域（靠左紧凑显示）
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _addNewBugForm,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('添加新BUG'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1890FF),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(120, 40),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitBugs,
                            child: _isSubmitting
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                                : const Text('提交所有BUG'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF52C41A),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _addNewBugForm,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('添加新BUG'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1890FF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitBugs,
                          child: _isSubmitting
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : const Text('提交所有BUG'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF52C41A),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // 表格内容区域（核心修复：靠左显示 + 移除完成时间/责任人列）
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // 移除左侧padding，让表格靠左显示
              child: Container(
                width: totalTableWidth,
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.green.shade50),
                    border: TableBorder.all(color: Colors.grey.shade200),
                    columnSpacing: 2, // 更小的列间距
                    horizontalMargin: 0, // 移除左右外边距
                    columns: [
                      DataColumn(label: SizedBox(width: cellWidth, child: const Text('编号', style: TextStyle(fontSize: 12)))),
                      DataColumn(label: SizedBox(width: wideCellWidth, child: const Text('问题描述', style: TextStyle(fontSize: 12)))),
                      DataColumn(label: SizedBox(width: cellWidth, child: const Text('提出时间', style: TextStyle(fontSize: 12)))),
                      DataColumn(label: SizedBox(width: cellWidth, child: const Text('问题分类', style: TextStyle(fontSize: 12)))),
                      DataColumn(label: SizedBox(width: cellWidth, child: const Text('复现概率', style: TextStyle(fontSize: 12)))),
                      DataColumn(label: SizedBox(width: cellWidth, child: const Text('严重等级', style: TextStyle(fontSize: 12)))),
                      DataColumn(label: SizedBox(width: cellWidth, child: const Text('发现版本', style: TextStyle(fontSize: 12)))),
                      DataColumn(label: SizedBox(width: cellWidth, child: const Text('提出人员', style: TextStyle(fontSize: 12)))),
                      DataColumn(label: SizedBox(width: wideCellWidth, child: const Text('问题分析', style: TextStyle(fontSize: 12)))),
                      DataColumn(label: SizedBox(width: cellWidth, child: const Text('评审结论', style: TextStyle(fontSize: 12)))),
                      DataColumn(label: SizedBox(width: cellWidth, child: const Text('备注', style: TextStyle(fontSize: 12)))),
                      DataColumn(label: SizedBox(width: narrowCellWidth, child: const Text('操作', style: TextStyle(fontSize: 12)))),
                    ],
                    rows: List.generate(_bugFormList.length, (index) {
                      final bug = _bugFormList[index];
                      return DataRow(
                        cells: [
                          DataCell(SizedBox(
                            width: cellWidth,
                            child: TextFormField(
                              initialValue: bug.bugNo,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(3)),
                              style: const TextStyle(fontSize: 12),
                              onChanged: (value) => bug.bugNo = value,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: wideCellWidth,
                            child: TextFormField(
                              initialValue: bug.problemDesc,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(3)),
                              style: const TextStyle(fontSize: 12),
                              onChanged: (value) => bug.problemDesc = value,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: cellWidth,
                            child: InkWell(
                              onTap: () => _selectDate(index),
                              child: Text(bug.createTime, style: const TextStyle(fontSize: 12)),
                            ),
                          )),
                          DataCell(SizedBox(
                            width: cellWidth,
                            child: EditableDropdown(
                              initialValue: bug.moduleType,
                              options: const ['固件', 'APP', '硬件', '其他'],
                              onChanged: (value) {
                                setState(() => bug.moduleType = value);
                              },
                              hintText: '问题分类',
                            ),
                          )),
                          DataCell(SizedBox(
                            width: cellWidth,
                            child: FixedDropdown(
                              value: bug.reproduceProb,
                              options: const ['必现', '偶现', '难现'],
                              onChanged: (value) {
                                setState(() => bug.reproduceProb = value);
                              },
                            ),
                          )),
                          DataCell(SizedBox(
                            width: cellWidth,
                            child: FixedDropdown(
                              // 移除「致命」选项，匹配后端枚举
                              value: bug.severity,
                              options: const ['轻微', '中等', '严重'],
                              onChanged: (value) {
                                setState(() => bug.severity = value);
                              },
                            ),
                          )),
                          DataCell(SizedBox(
                            width: cellWidth,
                            child: TextFormField(
                              initialValue: bug.foundVersion,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(3)),
                              style: const TextStyle(fontSize: 12),
                              onChanged: (value) => bug.foundVersion = value,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: cellWidth,
                            child: Text(_currentUsername.isEmpty ? '加载中...' : _currentUsername, style: const TextStyle(fontSize: 12)),
                          )),
                          DataCell(SizedBox(
                            width: wideCellWidth,
                            child: TextFormField(
                              initialValue: bug.analysis,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(3)),
                              style: const TextStyle(fontSize: 12),
                              onChanged: (value) => bug.analysis = value,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: cellWidth,
                            child: EditableDropdown(
                              // 匹配后端枚举值
                              initialValue: bug.reviewResult,
                              options: const ['无', '待评审', '通过', '未通过'],
                              onChanged: (value) {
                                setState(() => bug.reviewResult = value);
                              },
                              hintText: '评审结论',
                            ),
                          )),
                          DataCell(SizedBox(
                            width: cellWidth,
                            child: TextFormField(
                              initialValue: bug.remark,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(3)),
                              style: const TextStyle(fontSize: 12),
                              onChanged: (value) => bug.remark = value,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: narrowCellWidth,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                              onPressed: () => _removeBugForm(index),
                              padding: EdgeInsets.zero,
                            ),
                          )),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}