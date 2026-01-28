import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workflow/constants/api_constants.dart';
import 'package:workflow/dailylin/daily_report_model.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:workflow/dailylin/excel_export_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

// 自定义TextField，使用Flutter默认键盘处理逻辑
class CustomTextField extends StatefulWidget {
  final InputDecoration decoration;
  final String text;
  final Function(String) onChanged;
  final int? maxLines;

  const CustomTextField({
    super.key,
    required this.decoration,
    required this.text,
    required this.onChanged,
    required this.maxLines,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late String _lastWidgetText;
  bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();
    _lastWidgetText = widget.text;
    _controller = TextEditingController(text: widget.text);
    _focusNode = FocusNode();

    // 监听焦点变化，判断用户是否在交互
    _focusNode.addListener(() {
      final hadFocus = _isUserInteracting;
      _isUserInteracting = _focusNode.hasFocus;

      // 焦点丢失时，确保控制器文本与widget文本同步
      if (hadFocus && !_isUserInteracting) {
        if (widget.text != _controller.text) {
          _updateControllerText(widget.text);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 只有当widget.text确实发生变化时才更新控制器
    if (oldWidget.text != widget.text && widget.text != _controller.text) {
      _lastWidgetText = widget.text;

      // 如果用户正在交互（有焦点），跳过更新以避免干扰键盘状态
      // 等到焦点丢失时再同步（在焦点监听器中处理）
      if (!_isUserInteracting) {
        // 用户没有交互，直接更新
        _updateControllerText(widget.text);
      }
    }
  }

  void _updateControllerText(String newText) {
    // 保存当前选择状态
    final currentSelection = _controller.selection;
    final currentComposing = _controller.value.composing;

    _controller.value = _controller.value.copyWith(
      text: newText,
      selection: currentSelection,
      composing: currentComposing,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: widget.decoration,
      controller: _controller,
      focusNode: _focusNode,
      maxLines: widget.maxLines,
      onChanged: (value) {
        widget.onChanged(value);
      },
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.multiline,
      enableInteractiveSelection: true,
      enableSuggestions: true,
      autocorrect: false,
      enableIMEPersonalizedLearning: true,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      autofillHints: null,
      // 添加稳定的光标配置
      cursorHeight: 20,
      cursorWidth: 2,
      cursorOpacityAnimates: true,
      // 添加更多稳定化配置
      scrollPadding: const EdgeInsets.all(20),
      scrollPhysics: const ClampingScrollPhysics(),
    );
  }
}

class DailyReportPage extends StatefulWidget {
  const DailyReportPage({super.key});

  @override
  _DailyReportPageState createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String _userId = '';
  String _username = '';
  String _department = '';
  String _position = '';

  DailyReportModel? _report;
  final FocusNode _focusNode = FocusNode();

  // Debounce工具，用于减少频繁的状态更新
  Timer? _debounceTimer;

  void _debounceUpdate(
    Function() callback, {
    Duration delay = const Duration(milliseconds: 300),
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, callback);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _getUserInfo();
  }

  Future<void> _getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId') ?? '';
      _username = prefs.getString('username') ?? '';
      _department = prefs.getString('department') ?? '';
      _position = prefs.getString('position') ?? '';
    });
    _loadReport();
  }

  String _getDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadReport() async {
    if (_userId.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final dateStr = _getDateString(_selectedDate);
      final response = await http.get(
        Uri.parse('$baseUrl/api/report/$_userId/$dateStr'),
      );

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          try {
            final data = json.decode(response.body);
            if (data['success'] == true) {
              if (data['data'] != null) {
                _report = _parseReportFromData(data['data']);
              } else {
                print('API返回data=null: ${response.body}');
                _report = _createEmptyReport();
              }
            } else {
              print('API返回success=false: ${response.body}');
              _report = _createEmptyReport();
            }
          } catch (e) {
            print('JSON解析失败: $e, 响应内容: ${response.body}');
            _report = _createEmptyReport();
          }
        } else {
          print('API返回空响应体');
          _report = _createEmptyReport();
        }
      } else {
        print('HTTP错误 ${response.statusCode}: ${response.body}');
        _report = _createEmptyReport();
      }
    } catch (e) {
      print('加载日报失败: $e');
      _report = _createEmptyReport();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  DailyReportModel _createEmptyReport() {
    final dateStr = _getDateString(_selectedDate);
    return DailyReportModel.empty(
      _userId,
      dateStr,
      _username,
      _department,
      _position,
    );
  }

  DailyReportModel _parseReportFromData(dynamic data) {
    if (data == null) {
      return _createEmptyReport();
    }

    List<WorkItem> todayWork = _parseWorkItems(data['todayWork']);
    List<WorkItem> tomorrowPlan = _parseWorkItems(data['tomorrowPlan']);
    List<UnfinishedItem> unfinishedWork = _parseUnfinishedItems(
      data['unfinishedWork'],
    );

    return DailyReportModel(
      id: data['_id']?.toString(),
      userId: data['userId'] ?? _userId,
      date: data['date'] ?? _getDateString(_selectedDate),
      name: data['name'] ?? _username,
      department: data['department'] ?? _department,
      position: data['position'] ?? _position,
      todayWork: todayWork,
      tomorrowPlan: tomorrowPlan,
      unfinishedWork: unfinishedWork,
      selfEvaluation: data['selfEvaluation'] ?? 80,
      summary: data['summary'] ?? '',
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'])
          : DateTime.now(),
    );
  }

  List<WorkItem> _parseWorkItems(dynamic data) {
    List<WorkItem> items = [];
    if (data is List) {
      for (var item in data) {
        items.add(
          WorkItem(
            serial: item['serial'] ?? 0,
            timeRange: item['timeRange'] ?? '',
            importance: item['importance'] ?? '',
            content: item['content'] ?? '',
            output: item['output'] ?? '',
          ),
        );
      }
    }
    return items;
  }

  List<UnfinishedItem> _parseUnfinishedItems(dynamic data) {
    List<UnfinishedItem> items = [];
    if (data is List) {
      for (var item in data) {
        items.add(
          UnfinishedItem(
            serial: item['serial'] ?? 0,
            workContent: item['workContent'] ?? '',
            reason: item['reason'] ?? '',
            improvement: item['improvement'] ?? '',
          ),
        );
      }
    }
    return items;
  }

  Future<void> _saveReport() async {
    if (_userId.isEmpty || _report == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/report'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': _report!.userId,
          'date': _report!.date,
          'name': _report!.name,
          'department': _report!.department,
          'position': _report!.position,
          'todayWork': _report!.todayWork.map((item) => item.toMap()).toList(),
          'tomorrowPlan': _report!.tomorrowPlan
              .map((item) => item.toMap())
              .toList(),
          'unfinishedWork': _report!.unfinishedWork
              .map((item) => item.toMap())
              .toList(),
          'selfEvaluation': _report!.selfEvaluation,
          'summary': _report!.summary,
        }),
      );

      if (response.statusCode == 200) {
        try {
          if (response.body.isEmpty) {
            throw FormatException('服务器返回空响应');
          }
          final data = json.decode(response.body);
          if (data['success'] == true) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('保存成功')));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('保存失败: ${data['message'] ?? '未知错误'}')),
            );
          }
        } catch (e) {
          print('JSON解析失败: $e, 响应内容: ${response.body}');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('保存失败: 服务器响应格式错误')));
        }
      } else {
        String errorMessage;
        switch (response.statusCode) {
          case 400:
            errorMessage = '保存失败，请求参数错误';
            break;
          case 401:
            errorMessage = '保存失败，登录状态已过期，请重新登录';
            break;
          case 403:
            errorMessage = '保存失败，权限不足';
            break;
          case 404:
            errorMessage = '保存失败，服务器接口不存在';
            break;
          case 500:
            errorMessage = '保存失败，服务器内部错误';
            break;
          case 502:
            errorMessage = '保存失败，服务器网关错误';
            break;
          case 503:
            errorMessage = '保存失败，服务器暂时不可用';
            break;
          case 504:
            errorMessage = '保存失败，服务器响应超时';
            break;
          default:
            errorMessage = '保存失败，服务器错误 (${response.statusCode})';
        }
        print('HTTP错误 ${response.statusCode}: ${response.body}');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      print('保存日报失败: $e');
      String errorMessage;
      if (e is SocketException) {
        errorMessage = '保存失败，网络连接错误，请检查网络';
      } else if (e is TimeoutException) {
        errorMessage = '保存失败，请求超时，请稍后重试';
      } else if (e is FormatException) {
        errorMessage = '保存失败，数据格式错误';
      } else {
        errorMessage = '保存失败，请重试';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportToExcel() async {
    // 移除焦点，避免键盘状态不一致问题
    FocusScope.of(context).unfocus();

    if (_report == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('没有可导出的数据')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 生成Excel文件
      final bytes = await ExcelExportService.exportDailyReportToExcel(_report!);

      // 获取下载目录
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('无法获取下载目录');
      }

      // 创建文件名：日报_日期_时间.xlsx
      final now = DateTime.now();
      final fileName =
          '日报_${_report!.date}_${now.hour}${now.minute}${now.second}.xlsx';
      final file = File('${directory.path}/$fileName');

      // 保存文件
      await file.writeAsBytes(bytes);

      // 打开文件
      await OpenFile.open(file.path);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Excel导出成功: $fileName')));
    } catch (e) {
      print('Excel导出失败: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出失败: ${e.toString()}')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateReport(DailyReportModel Function(DailyReportModel) updater) {
    if (_report == null) return;
    setState(() {
      _report = updater(_report!);
    });
  }

  void _debouncedUpdateReport(
    DailyReportModel Function(DailyReportModel) updater,
  ) {
    if (_report == null) return;
    _debounceUpdate(() {
      if (mounted) {
        setState(() {
          _report = updater(_report!);
        });
      }
    }, delay: const Duration(milliseconds: 300));
  }

  // 为避免中文输入重复，使用更简单的TextField配置
  Widget _buildTextField(
    String label,
    String text,
    Function(String) onChanged, {
    int? maxLines = 1,
  }) {
    return _buildCustomTextField(
      decoration: InputDecoration(labelText: label),
      text: text,
      onChanged: onChanged,
      maxLines: maxLines,
    );
  }

  Widget _buildCollapsedTextField(
    String hint,
    String text,
    Function(String) onChanged, {
    int? maxLines = null,
  }) {
    return _buildCustomTextField(
      decoration: InputDecoration.collapsed(hintText: hint),
      text: text,
      onChanged: onChanged,
      maxLines: maxLines,
    );
  }

  // 自定义TextField，解决删除和输入问题
  Widget _buildCustomTextField({
    required InputDecoration decoration,
    required String text,
    required Function(String) onChanged,
    required int? maxLines,
  }) {
    return CustomTextField(
      decoration: decoration,
      text: text,
      onChanged: onChanged,
      maxLines: maxLines,
    );
  }

  void _updateTodayWorkItem(int index, WorkItem Function(WorkItem) updater) {
    if (_report == null || index < 0 || index >= _report!.todayWork.length)
      return;
    _updateReport((report) {
      List<WorkItem> updatedWork = List.from(report.todayWork);
      updatedWork[index] = updater(updatedWork[index]);
      return DailyReportModel(
        id: report.id,
        userId: report.userId,
        date: report.date,
        name: report.name,
        department: report.department,
        position: report.position,
        todayWork: updatedWork,
        tomorrowPlan: report.tomorrowPlan,
        unfinishedWork: report.unfinishedWork,
        selfEvaluation: report.selfEvaluation,
        summary: report.summary,
        createdAt: report.createdAt,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _updateTomorrowPlanItem(int index, WorkItem Function(WorkItem) updater) {
    if (_report == null || index < 0 || index >= _report!.tomorrowPlan.length)
      return;
    _updateReport((report) {
      List<WorkItem> updatedPlan = List.from(report.tomorrowPlan);
      updatedPlan[index] = updater(updatedPlan[index]);
      return DailyReportModel(
        id: report.id,
        userId: report.userId,
        date: report.date,
        name: report.name,
        department: report.department,
        position: report.position,
        todayWork: report.todayWork,
        tomorrowPlan: updatedPlan,
        unfinishedWork: report.unfinishedWork,
        selfEvaluation: report.selfEvaluation,
        summary: report.summary,
        createdAt: report.createdAt,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _updateUnfinishedWorkItem(
    int index,
    UnfinishedItem Function(UnfinishedItem) updater,
  ) {
    if (_report == null || index < 0 || index >= _report!.unfinishedWork.length)
      return;
    _updateReport((report) {
      List<UnfinishedItem> updatedUnfinished = List.from(report.unfinishedWork);
      updatedUnfinished[index] = updater(updatedUnfinished[index]);
      return DailyReportModel(
        id: report.id,
        userId: report.userId,
        date: report.date,
        name: report.name,
        department: report.department,
        position: report.position,
        todayWork: report.todayWork,
        tomorrowPlan: report.tomorrowPlan,
        unfinishedWork: updatedUnfinished,
        selfEvaluation: report.selfEvaluation,
        summary: report.summary,
        createdAt: report.createdAt,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _addTodayWorkItem() {
    if (_report == null) return;
    _updateReport((report) {
      List<WorkItem> updatedWork = List.from(report.todayWork);
      updatedWork.add(
        WorkItem(
          serial: updatedWork.length + 1,
          timeRange: '',
          importance: '',
          content: '',
          output: '',
        ),
      );
      return DailyReportModel(
        id: report.id,
        userId: report.userId,
        date: report.date,
        name: report.name,
        department: report.department,
        position: report.position,
        todayWork: updatedWork,
        tomorrowPlan: report.tomorrowPlan,
        unfinishedWork: report.unfinishedWork,
        selfEvaluation: report.selfEvaluation,
        summary: report.summary,
        createdAt: report.createdAt,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _addTomorrowPlanItem() {
    if (_report == null) return;
    _updateReport((report) {
      List<WorkItem> updatedPlan = List.from(report.tomorrowPlan);
      updatedPlan.add(
        WorkItem(
          serial: updatedPlan.length + 1,
          timeRange: '',
          importance: '',
          content: '',
          output: '',
        ),
      );
      return DailyReportModel(
        id: report.id,
        userId: report.userId,
        date: report.date,
        name: report.name,
        department: report.department,
        position: report.position,
        todayWork: report.todayWork,
        tomorrowPlan: updatedPlan,
        unfinishedWork: report.unfinishedWork,
        selfEvaluation: report.selfEvaluation,
        summary: report.summary,
        createdAt: report.createdAt,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _addUnfinishedWorkItem() {
    if (_report == null) return;
    _updateReport((report) {
      List<UnfinishedItem> updatedUnfinished = List.from(report.unfinishedWork);
      updatedUnfinished.add(
        UnfinishedItem(
          serial: updatedUnfinished.length + 1,
          workContent: '',
          reason: '',
          improvement: '',
        ),
      );
      return DailyReportModel(
        id: report.id,
        userId: report.userId,
        date: report.date,
        name: report.name,
        department: report.department,
        position: report.position,
        todayWork: report.todayWork,
        tomorrowPlan: report.tomorrowPlan,
        unfinishedWork: updatedUnfinished,
        selfEvaluation: report.selfEvaluation,
        summary: report.summary,
        createdAt: report.createdAt,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<void> _selectDate() async {
    // 添加延迟，确保视图已经完全渲染
    await Future.delayed(Duration(milliseconds: 100));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF0088FF),
            colorScheme: const ColorScheme.light(primary: Color(0xFF0088FF)),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _report == null) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部日期选择栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                ElevatedButton.icon(
                  onPressed: _selectDate,
                  icon: Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: Text('选择日期', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0088FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // 基本信息
          Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '基本信息',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField('姓名', _report!.name, (value) {
                          _debouncedUpdateReport(
                            (report) => DailyReportModel(
                              id: report.id,
                              userId: report.userId,
                              date: report.date,
                              name: value,
                              department: report.department,
                              position: report.position,
                              todayWork: report.todayWork,
                              tomorrowPlan: report.tomorrowPlan,
                              unfinishedWork: report.unfinishedWork,
                              selfEvaluation: report.selfEvaluation,
                              summary: report.summary,
                              createdAt: report.createdAt,
                              updatedAt: DateTime.now(),
                            ),
                          );
                        }),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('部门', _report!.department, (
                          value,
                        ) {
                          _debouncedUpdateReport(
                            (report) => DailyReportModel(
                              id: report.id,
                              userId: report.userId,
                              date: report.date,
                              name: report.name,
                              department: value,
                              position: report.position,
                              todayWork: report.todayWork,
                              tomorrowPlan: report.tomorrowPlan,
                              unfinishedWork: report.unfinishedWork,
                              selfEvaluation: report.selfEvaluation,
                              summary: report.summary,
                              createdAt: report.createdAt,
                              updatedAt: DateTime.now(),
                            ),
                          );
                        }),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('岗位', _report!.position, (
                          value,
                        ) {
                          _debouncedUpdateReport(
                            (report) => DailyReportModel(
                              id: report.id,
                              userId: report.userId,
                              date: report.date,
                              name: report.name,
                              department: report.department,
                              position: value,
                              todayWork: report.todayWork,
                              tomorrowPlan: report.tomorrowPlan,
                              unfinishedWork: report.unfinishedWork,
                              selfEvaluation: report.selfEvaluation,
                              summary: report.summary,
                              createdAt: report.createdAt,
                              updatedAt: DateTime.now(),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 今日工作
          Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日工作 (DO: 执行)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  // 今日工作表格
                  Table(
                    border: TableBorder.all(),
                    children: [
                      TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                '序号',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                '工作时间',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                '重要程度',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                '具体内容',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                '输出成果',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      for (int i = 0; i < _report!.todayWork.length; i++)
                        TableRow(
                          children: [
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  '${i + 1}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: _buildCollapsedTextField(
                                  '时间段',
                                  _report!.todayWork[i].timeRange,
                                  (value) {
                                    _updateTodayWorkItem(
                                      i,
                                      (item) => WorkItem(
                                        serial: item.serial,
                                        timeRange: value,
                                        importance: item.importance,
                                        content: item.content,
                                        output: item.output,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: _buildCollapsedTextField(
                                  'A/B/C/D',
                                  _report!.todayWork[i].importance,
                                  (value) {
                                    _updateTodayWorkItem(
                                      i,
                                      (item) => WorkItem(
                                        serial: item.serial,
                                        timeRange: item.timeRange,
                                        importance: value,
                                        content: item.content,
                                        output: item.output,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: _buildCollapsedTextField(
                                  '工作内容',
                                  _report!.todayWork[i].content,
                                  (value) {
                                    _updateTodayWorkItem(
                                      i,
                                      (item) => WorkItem(
                                        serial: item.serial,
                                        timeRange: item.timeRange,
                                        importance: item.importance,
                                        content: value,
                                        output: item.output,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: _buildCollapsedTextField(
                                  '成果',
                                  _report!.todayWork[i].output,
                                  (value) {
                                    _updateTodayWorkItem(
                                      i,
                                      (item) => WorkItem(
                                        serial: item.serial,
                                        timeRange: item.timeRange,
                                        importance: item.importance,
                                        content: item.content,
                                        output: value,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addTodayWorkItem,
                    icon: Icon(Icons.add),
                    label: Text('添加工作项'),
                  ),
                ],
              ),
            ),
          ),

          // 明日计划
          Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '明日工作计划 (PLAN: 计划)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  // 明日计划表格
                  Table(
                    border: TableBorder.all(),
                    children: [
                      TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                '序号',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                '工作时间',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                '重要程度',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                '具体内容',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                '输出成果',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      for (int i = 0; i < _report!.tomorrowPlan.length; i++)
                        TableRow(
                          children: [
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  '${i + 1}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: _buildCollapsedTextField(
                                  '时间段',
                                  _report!.tomorrowPlan[i].timeRange,
                                  (value) {
                                    _updateTomorrowPlanItem(
                                      i,
                                      (item) => WorkItem(
                                        serial: item.serial,
                                        timeRange: value,
                                        importance: item.importance,
                                        content: item.content,
                                        output: item.output,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: _buildCollapsedTextField(
                                  'A/B/C/D',
                                  _report!.tomorrowPlan[i].importance,
                                  (value) {
                                    _updateTomorrowPlanItem(
                                      i,
                                      (item) => WorkItem(
                                        serial: item.serial,
                                        timeRange: item.timeRange,
                                        importance: value,
                                        content: item.content,
                                        output: item.output,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: _buildCollapsedTextField(
                                  '工作内容',
                                  _report!.tomorrowPlan[i].content,
                                  (value) {
                                    _updateTomorrowPlanItem(
                                      i,
                                      (item) => WorkItem(
                                        serial: item.serial,
                                        timeRange: item.timeRange,
                                        importance: item.importance,
                                        content: value,
                                        output: item.output,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: _buildCollapsedTextField(
                                  '成果',
                                  _report!.tomorrowPlan[i].output,
                                  (value) {
                                    _updateTomorrowPlanItem(
                                      i,
                                      (item) => WorkItem(
                                        serial: item.serial,
                                        timeRange: item.timeRange,
                                        importance: item.importance,
                                        content: item.content,
                                        output: value,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addTomorrowPlanItem,
                    icon: Icon(Icons.add),
                    label: Text('添加计划项'),
                  ),
                ],
              ),
            ),
          ),

          // 未完成工作
          Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日未完成工作 (CHECK: 检查)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  // 未完成工作表格
                  Table(
                    border: TableBorder.all(),
                    children: [
                      TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                '序号',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                '工作内容',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                '未完成原因',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                '改进措施',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      for (int i = 0; i < _report!.unfinishedWork.length; i++)
                        TableRow(
                          children: [
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  '${i + 1}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: _buildCollapsedTextField(
                                  '工作内容',
                                  _report!.unfinishedWork[i].workContent,
                                  (value) {
                                    _updateUnfinishedWorkItem(
                                      i,
                                      (item) => UnfinishedItem(
                                        serial: item.serial,
                                        workContent: value,
                                        reason: item.reason,
                                        improvement: item.improvement,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: _buildCollapsedTextField(
                                  '原因',
                                  _report!.unfinishedWork[i].reason,
                                  (value) {
                                    _updateUnfinishedWorkItem(
                                      i,
                                      (item) => UnfinishedItem(
                                        serial: item.serial,
                                        workContent: item.workContent,
                                        reason: value,
                                        improvement: item.improvement,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: _buildCollapsedTextField(
                                  '措施',
                                  _report!.unfinishedWork[i].improvement,
                                  (value) {
                                    _updateUnfinishedWorkItem(
                                      i,
                                      (item) => UnfinishedItem(
                                        serial: item.serial,
                                        workContent: item.workContent,
                                        reason: item.reason,
                                        improvement: value,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addUnfinishedWorkItem,
                    icon: Icon(Icons.add),
                    label: Text('添加未完成项'),
                  ),
                  SizedBox(height: 16),
                  // 今日自评
                  Row(
                    children: [
                      Text('今日自评: ', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          '评分 (0-100)',
                          _report!.selfEvaluation.toString(),
                          (value) {
                            int score = int.tryParse(value) ?? 80;
                            _debouncedUpdateReport(
                              (report) => DailyReportModel(
                                id: report.id,
                                userId: report.userId,
                                date: report.date,
                                name: report.name,
                                department: report.department,
                                position: report.position,
                                todayWork: report.todayWork,
                                tomorrowPlan: report.tomorrowPlan,
                                unfinishedWork: report.unfinishedWork,
                                selfEvaluation: score,
                                summary: report.summary,
                                createdAt: report.createdAt,
                                updatedAt: DateTime.now(),
                              ),
                            );
                          },
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 今日总结
          Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日总结',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  _buildTextField('请输入今日工作总结...', _report!.summary, (value) {
                    _debouncedUpdateReport(
                      (report) => DailyReportModel(
                        id: report.id,
                        userId: report.userId,
                        date: report.date,
                        name: report.name,
                        department: report.department,
                        position: report.position,
                        todayWork: report.todayWork,
                        tomorrowPlan: report.tomorrowPlan,
                        unfinishedWork: report.unfinishedWork,
                        selfEvaluation: report.selfEvaluation,
                        summary: value,
                        createdAt: report.createdAt,
                        updatedAt: DateTime.now(),
                      ),
                    );
                  }, maxLines: 5),
                ],
              ),
            ),
          ),

          // 保存与导出按钮
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveReport,
                  child: Text('保存日报'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0088FF),
                    minimumSize: Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _exportToExcel,
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text('导出Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF4CAF50),
                    minimumSize: Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}
