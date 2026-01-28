import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:developer' as dev;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

// 导入同目录下的Apply_List_Page.dart（获取数据模型）
import 'Apply_List_Page.dart';
import 'apply_model.dart';

/// PDF生成配置枚举（区分两种生成模式）
enum PdfGenerateMode {
  withDetailInfo, // 生成负责人详细信息（1排4列）
  withoutDetailInfo, // 五排六列+显示负责人（分行）+字体放大一倍
}

/// PDF生成工具类（封装所有PDF相关逻辑）
class PdfGenerator {
  /// 加载中文字体（供内部使用，封装为私有方法）
  static Future<pw.Font> _loadChineseFont() async {
    dev.log('开始加载项目内置中文字体', name: 'PDF生成');
    try {
      ByteData fontByteData;
      if (Platform.isWindows) {
        fontByteData = await rootBundle.load('assets/fonts/arialuni.ttf');
      } else if (Platform.isMacOS) {
        fontByteData = await rootBundle.load('assets/fonts/PingFang.ttc');
      } else {
        fontByteData = await rootBundle.load('assets/fonts/arialuni.ttf');
      }

      dev.log('加载项目内置字体成功', name: 'PDF生成');
      return pw.Font.ttf(fontByteData);
    } catch (e) {
      dev.log('项目内置字体加载失败：$e', name: 'PDF生成', error: e);
      rethrow;
    }
  }

  /// 文本截断工具（封装为私有方法，保持原有逻辑）
  static String _truncateText(String content, int maxLength) {
    if (content.isEmpty) return content;
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}...';
  }

  /// 构建带负责人详细信息的任务卡片（1排4列专用）
  static pw.Widget _buildTaskCardWithDetail(ApplyModel apply, pw.Font font) {
    String statusText = apply.overallStatusCn;
    PdfColor statusColor = apply.overallStatus == 'completed' ? PdfColors.green : PdfColors.orange;

    final PdfColor grey300 = PdfColor(0.8, 0.8, 0.8);
    final PdfColor lightBlue = PdfColor(0.9, 0.95, 1.0);

    // 文本截断（保持原有逻辑）
    String truncatedCustomer = _truncateText('客户：${apply.customer}', 15);
    String truncatedBusiness = _truncateText('业务：${apply.business}', 15);
    String truncatedLeader = _truncateText('组长：${apply.leaderName}', 15);
    String truncatedApplicant = _truncateText('申请人：${apply.applicant}', 15);
    String truncatedHardware = _truncateText(
        '硬件：${apply.hardwareHandlers.isNotEmpty ? apply.hardwareHandlers.join('、') : '无'}',
        18
    );
    String truncatedSoftware = _truncateText(
        '软件：${apply.softwareHandlers.isNotEmpty ? apply.softwareHandlers.join('、') : '无'}',
        18
    );
    String truncatedTest = _truncateText(
        '测试：${apply.testHandlers.isNotEmpty ? apply.testHandlers.join('、') : '无'}',
        18
    );

    return pw.Container(
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: grey300, width: 1.0),
        borderRadius: pw.BorderRadius.circular(6),
        boxShadow: [pw.BoxShadow(color: PdfColors.grey200, blurRadius: 2.0)],
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          // 客户+状态
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                truncatedCustomer,
                style: pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: statusColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  statusText,
                  style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.white),
                ),
              ),
            ],
          ),
          pw.Divider(thickness: 0.8, color: PdfColors.grey400, height: 8),

          // 基础信息
          pw.Text(truncatedBusiness, style: pw.TextStyle(font: font, fontSize: 12)),
          pw.Text(truncatedLeader, style: pw.TextStyle(font: font, fontSize: 12)),
          pw.Text(truncatedApplicant, style: pw.TextStyle(font: font, fontSize: 12)),
          pw.Divider(thickness: 0.8, color: PdfColors.grey400, height: 8),

          // 负责人
          pw.Text(truncatedHardware, style: pw.TextStyle(font: font, fontSize: 11)),
          pw.Text(truncatedSoftware, style: pw.TextStyle(font: font, fontSize: 11)),
          pw.Text(truncatedTest, style: pw.TextStyle(font: font, fontSize: 11)),
          pw.Divider(thickness: 0.8, color: PdfColors.grey400, height: 8),

          // 时间
          pw.Text('申请时间：${apply.applyTime}', style: pw.TextStyle(font: font, fontSize: 11)),
          pw.Text('预计完成：${apply.expectedCompletionTime}', style: pw.TextStyle(font: font, fontSize: 11)),
          pw.Divider(thickness: 0.8, color: PdfColors.grey400, height: 8),

          // 任务详情（带详细信息）
          pw.Text('任务详情：', style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          // 显式转换为List<pw.Widget>（解决List<dynamic>无法赋值问题）
          ...apply.responsibleDetails.map<pw.Widget>((detail) {
            String truncatedTask = _truncateText(detail.taskContent, 20);
            String status = detail.personalStatusCn;
            PdfColor taskStatusColor = detail.pdfStatusColor;

            return pw.Container(
              margin: pw.EdgeInsets.only(bottom: 4),
              padding: pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: pw.BoxDecoration(
                color: lightBlue,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${detail.roleCn}(${detail.username})',
                        style: pw.TextStyle(font: font, fontSize: 11),
                      ),
                      pw.Container(
                        padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: taskStatusColor, width: 0.8),
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          status,
                          style: pw.TextStyle(font: font, fontSize: 9, color: taskStatusColor),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '任务：$truncatedTask',
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                  pw.Text(
                    '时间：${detail.startTime ?? "未开始"} - ${detail.completeTime ?? "未完成"}',
                    style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// 构建不带详细信息但显示负责人的任务卡片（5排6列专用·字体放大一倍·负责人分行）
  static pw.Widget _buildTaskCardWithoutDetail(ApplyModel apply, pw.Font font) {
    String statusText = apply.overallStatusCn;
    PdfColor statusColor = apply.overallStatus == 'done' ? PdfColors.green : PdfColors.orange;

    final PdfColor grey300 = PdfColor(0.8, 0.8, 0.8);

    // 文本截断（适配字体放大和分行布局，适当缩短截断长度）
    String truncatedCustomer = _truncateText('客户：${apply.customer}', 8);
    String truncatedBusiness = _truncateText('业务：${apply.business}', 8);

    // 核心修改：负责人分行展示（不再拼接为单个字符串，而是构建List<pw.Widget>）
    List<pw.Widget> handlerWidgets = [];
    // 1. 硬件负责人（分行）
    if (apply.hardwareHandlers.isNotEmpty) {
      String hardwareText = _truncateText('硬件：${apply.hardwareHandlers.join('、')}', 12);
      handlerWidgets.add(
        pw.Text(
          hardwareText,
          style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey800),
        ),
      );
    }
    // 2. 软件负责人（分行）
    if (apply.softwareHandlers.isNotEmpty) {
      String softwareText = _truncateText('软件：${apply.softwareHandlers.join('、')}', 12);
      handlerWidgets.add(
        pw.Text(
          softwareText,
          style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey800),
        ),
      );
    }
    // 3. 测试负责人（分行）
    if (apply.testHandlers.isNotEmpty) {
      String testText = _truncateText('测试：${apply.testHandlers.join('、')}', 12);
      handlerWidgets.add(
        pw.Text(
          testText,
          style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey800),
        ),
      );
    }
    // 4. 无负责人兜底
    if (handlerWidgets.isEmpty) {
      handlerWidgets.add(
        pw.Text(
          '无负责人',
          style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey800),
        ),
      );
    }

    return pw.Container(
      padding: pw.EdgeInsets.all(10), // 进一步增大内边距，适配分行后的负责人信息
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: grey300, width: 0.8),
        borderRadius: pw.BorderRadius.circular(4),
        boxShadow: [pw.BoxShadow(color: PdfColors.grey200, blurRadius: 1.0, spreadRadius: 0.1)],
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          // 客户+状态（字体放大一倍：原7→14，原6→12）
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                truncatedCustomer,
                style: pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: statusColor,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Text(
                  statusText,
                  style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.white),
                ),
              ),
            ],
          ),
          pw.Divider(thickness: 0.6, color: PdfColors.grey400, height: 8), // 增大分割线间距，适配布局

          // 简化基础信息（字体放大一倍：原6→12）
          pw.Text(truncatedBusiness, style: pw.TextStyle(font: font, fontSize: 12)),
          pw.Divider(thickness: 0.6, color: PdfColors.grey400, height: 8),

          // 核心修改：插入分行的负责人信息（使用展开运算符展示List<pw.Widget>）
          ...handlerWidgets,
          pw.Divider(thickness: 0.6, color: PdfColors.grey400, height: 8),

          // 简化时间信息（字体放大一倍：原5→10）
          pw.Text('申请：${apply.applyTime}', style: pw.TextStyle(font: font, fontSize: 10)),
          pw.Text('预计：${apply.expectedCompletionTime}', style: pw.TextStyle(font: font, fontSize: 10)),
        ],
      ),
    );
  }

  /// 选择PDF保存路径（修复Windows路径参数错误）
  static Future<String?> _selectSavePath(String? lastSavePath) async {
    try {
      String? initialDir;

      // 修复1：安全获取Windows用户目录，避免环境变量为空
      if (Platform.isWindows) {
        // 优先使用历史路径 → 其次使用桌面 → 最后使用文档目录
        if (lastSavePath != null && Directory(lastSavePath).existsSync()) {
          initialDir = lastSavePath;
        } else {
          // 获取桌面路径（更稳定）
          String? userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null && userProfile.isNotEmpty) {
            initialDir = '$userProfile\\Desktop';
          } else {
            initialDir = 'C:\\Users\\Public\\Documents'; // 公共目录兜底
          }
        }
      } else if (Platform.isMacOS) {
        initialDir = lastSavePath ?? '${Platform.environment['HOME']}/Documents';
      } else {
        initialDir = lastSavePath ?? Directory.current.path;
      }

      // 修复2：移除initialDirectory参数的强制传递（避免参数格式错误）
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择PDF保存位置',
        // 注释掉可能引发参数错误的initialDirectory
        // initialDirectory: initialDir,
      );

      if (result == null) {
        dev.log('用户取消了路径选择', name: 'PDF生成');
        return null;
      }

      // 验证路径有效性
      if (!Directory(result).existsSync()) {
        dev.log('选择的路径不存在：$result', name: 'PDF生成');
        return null;
      }

      dev.log('用户选择的保存路径：$result', name: 'PDF生成');
      return result;
    } catch (e) {
      dev.log('路径选择失败：$e', name: 'PDF生成', error: e);
      // 降级方案：使用应用临时目录
      String fallbackDir = Directory.systemTemp.path;
      dev.log('使用降级路径：$fallbackDir', name: 'PDF生成');
      return fallbackDir;
    }
  }

  /// 保存PDF文件并返回文件路径（封装为私有方法）
  static Future<String> _savePdfFile(Uint8List pdfBytes, String saveDir, PdfGenerateMode mode) async {
    final String modeDesc = mode == PdfGenerateMode.withDetailInfo
        ? '带详细信息'
        : '五排六列（含负责人·分行·字体放大）';
    final fileName = '所有任务汇总_${modeDesc}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    String filePath = Platform.isWindows
        ? '$saveDir\\$fileName'
        : '$saveDir/$fileName';

    await File(filePath).writeAsBytes(pdfBytes);
    dev.log('PDF保存成功，路径：$filePath', name: 'PDF生成');
    return filePath;
  }

  /// 构建PDF筛选条件文本（封装为私有方法）
  static String _buildFilterCondition({
    DateTime? startDate,
    DateTime? endDate,
    String? searchKeyword,
    required DateFormat dateFormatter,
  }) {
    String dateCondition = startDate != null
        ? '${dateFormatter.format(startDate)} 至 ${dateFormatter.format(endDate ?? DateTime.now())}'
        : '近一个月';
    String keywordCondition = searchKeyword?.isNotEmpty == true ? searchKeyword! : '全部';
    return '筛选条件：$dateCondition | 关键词：$keywordCondition';
  }

  /// 对外暴露的核心方法：生成并保存任务汇总PDF
  static Future<void> generateTaskPdf({
    required List<ApplyModel> taskList,
    required PdfGenerateMode mode,
    String? lastSavePath,
    DateTime? startDate,
    DateTime? endDate,
    String? searchKeyword,
    required Function(String filePath) onSuccess,
    required Function(String errorMsg) onError,
  }) async {
    // 校验任务列表是否为空
    if (taskList.isEmpty) {
      onError('⚠️ 没有可生成的申请数据，无法生成PDF');
      return;
    }

    try {
      // 1. 选择保存路径
      final saveDir = await _selectSavePath(lastSavePath);
      if (saveDir == null) {
        return;
      }

      // 2. 加载中文字体
      final chineseFont = await _loadChineseFont();
      final pdf = pw.Document();

      // 3. 配置不同模式的分页/卡片参数（适配选项2分行+字体放大后的布局）
      late int itemsPerPage;
      late double cardWidth;
      late double cardHeight;
      late pw.Widget Function(ApplyModel, pw.Font) buildCard;
      late String pageTitleSuffix;

      if (mode == PdfGenerateMode.withDetailInfo) {
        // 模式1：带详细信息（1排4列，单页4个）
        itemsPerPage = 4;
        cardWidth = (500.0 * PdfPageFormat.mm - 30) / 4 - 15;
        cardHeight = 220.0 * PdfPageFormat.mm;
        buildCard = _buildTaskCardWithDetail;
        pageTitleSuffix = '（带负责人详细信息）';
      } else {
        // 模式2：五排六列（单页30个=5*6，适配分行+字体放大后的卡片尺寸）
        itemsPerPage = 30;
        cardWidth = (500.0 * PdfPageFormat.mm - 100) / 6 - 12; // 进一步增大水平间距，适配分行布局
        cardHeight = (350.0 * PdfPageFormat.mm - 120) / 5 - 12; // 进一步增大垂直间距，适配分行后的高度
        buildCard = _buildTaskCardWithoutDetail;
        pageTitleSuffix = '（五排六列·含负责人·分行·字体放大）';
      }

      final int totalPages = (taskList.length / itemsPerPage).ceil();
      final DateFormat dateFormatter = DateFormat('yyyy-MM-dd');
      final String filterCondition = _buildFilterCondition(
        startDate: startDate,
        endDate: endDate,
        searchKeyword: searchKeyword,
        dateFormatter: dateFormatter,
      );

      // 4. 构建每一页PDF内容（适配分行+字体放大后的间距）
      for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        final int startIndex = pageIndex * itemsPerPage;
        final int endIndex = (startIndex + itemsPerPage) > taskList.length
            ? taskList.length
            : (startIndex + itemsPerPage);
        final List<ApplyModel> currentPageItems = taskList.sublist(startIndex, endIndex);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(
              500.0 * PdfPageFormat.mm,
              350.0 * PdfPageFormat.mm,
            ),
            margin: pw.EdgeInsets.only(top: 10, left: 15, right: 15, bottom: 10),
            build: (pw.Context context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.max,
              children: [
                // 标题+时间行
                pw.Center(
                  child: pw.Text(
                    '所有任务汇总报告$pageTitleSuffix（第${pageIndex + 1}/${totalPages}页）',
                    style: pw.TextStyle(
                      font: chineseFont,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueAccent,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '生成时间：${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
                      style: pw.TextStyle(font: chineseFont, fontSize: 12),
                    ),
                    pw.Text(
                      '本页数据：${currentPageItems.length} 条 | 总数据：${taskList.length} 条',
                      style: pw.TextStyle(font: chineseFont, fontSize: 12),
                    ),
                  ],
                ),
                pw.Text(
                  filterCondition,
                  style: pw.TextStyle(font: chineseFont, fontSize: 12, color: PdfColors.grey700),
                ),
                pw.Divider(thickness: 1.0, color: PdfColors.grey, height: 10),
                // 任务卡片列表（适配分行+字体放大后的布局，进一步增大间距）
                pw.Expanded(
                  child: pw.Align(
                    alignment: pw.Alignment.topCenter,
                    child: pw.Wrap(
                      direction: pw.Axis.horizontal,
                      spacing: mode == PdfGenerateMode.withDetailInfo ? 15 : 12,
                      runSpacing: mode == PdfGenerateMode.withDetailInfo ? 15 : 12,
                      children: currentPageItems.map((apply) {
                        return pw.Container(
                          width: cardWidth,
                          height: cardHeight,
                          child: buildCard(apply, chineseFont),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // 5. 保存PDF并回调成功结果
      final pdfBytes = await pdf.save();
      final filePath = await _savePdfFile(pdfBytes, saveDir, mode);
      onSuccess(filePath);

      // 6. 自动打开PDF文件
      await OpenFile.open(filePath);
    } catch (e) {
      dev.log('PDF生成失败：$e', name: 'PDF生成', error: e);
      onError('❌ PDF生成失败：${e.toString()}');
    }
  }
}