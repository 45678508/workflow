import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:workflow/dailylin/daily_report_model.dart';

class ExcelExportService {
  static Future<Uint8List> exportDailyReportToExcel(
    DailyReportModel report,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['工作日报'];

    // 1. 标题行：合并 A1 到 F1，显示 "工作日报"
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('工作日报');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 18,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('F1'));

    // 2. 基本信息行：第2行，A2到H2，共8个单元格
    final basicInfoRow = 2;
    final basicInfoLabels = [
      '姓名',
      report.name,
      '部门',
      report.department,
      '岗位',
      report.position,
      '填表日期',
      report.date,
    ];

    for (int i = 0; i < basicInfoLabels.length; i++) {
      final col = i; // A=0, B=1, ..., H=7
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: col,
          rowIndex: basicInfoRow - 1,
        ),
      );
      cell.value = TextCellValue(basicInfoLabels[i]);
      cell.cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    // 3. 今日工作（DO: 执行）模块
    // 3.1 模块标题：合并 A3 到 F3
    final todayWorkTitleRow = 3;
    final todayWorkTitleCell = sheet.cell(
      CellIndex.indexByString('A$todayWorkTitleRow'),
    );
    todayWorkTitleCell.value = TextCellValue('今日工作 (DO: 执行)');
    todayWorkTitleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    sheet.merge(
      CellIndex.indexByString('A$todayWorkTitleRow'),
      CellIndex.indexByString('F$todayWorkTitleRow'),
    );

    // 3.2 表头行：第4行
    final todayWorkHeaderRow = 4;
    final todayWorkHeaders = ['序号', '工作时间', '重要程度', '具体内容', '输出成果', ''];
    for (int i = 0; i < todayWorkHeaders.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: i,
          rowIndex: todayWorkHeaderRow - 1,
        ),
      );
      cell.value = TextCellValue(todayWorkHeaders[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    // 3.3 数据行：第5-14行，共10行
    // 生成上午时间段：8:30-12:00，分4个时间段
    final morningTimeRanges = [
      '8:30-9:30',
      '9:30-10:30',
      '10:30-11:30',
      '11:30-12:00',
    ];

    // 生成下午时间段：13:30-18:00，分5个时间段
    final afternoonTimeRanges = [
      '13:30-14:30',
      '14:30-15:30',
      '15:30-16:30',
      '16:30-17:30',
      '17:30-18:00',
    ];

    // 勤勉时间
    final diligenceTimeRange = '18:30-';

    // 填充今日工作数据
    int currentRow = 5;
    int serialNumber = 1;

    // 上午4个时间段
    for (int i = 0; i < morningTimeRanges.length; i++) {
      final row = currentRow + i;
      // 序号
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        serialNumber.toString(),
      );
      serialNumber++;
      // 工作时间
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
        morningTimeRanges[i],
      );
    }

    // 合并上午的"重要程度"单元格（C5:C8）
    sheet.merge(CellIndex.indexByString('C5'), CellIndex.indexByString('C8'));
    final morningImportanceCell = sheet.cell(CellIndex.indexByString('C5'));
    morningImportanceCell.value = TextCellValue('A');
    morningImportanceCell.cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    currentRow += morningTimeRanges.length;

    // 下午5个时间段
    for (int i = 0; i < afternoonTimeRanges.length; i++) {
      final row = currentRow + i;
      // 序号
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        serialNumber.toString(),
      );
      serialNumber++;
      // 工作时间
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
        afternoonTimeRanges[i],
      );
    }

    // 合并下午的"重要程度"单元格（C9:C13）
    sheet.merge(CellIndex.indexByString('C9'), CellIndex.indexByString('C13'));
    final afternoonImportanceCell = sheet.cell(CellIndex.indexByString('C9'));
    afternoonImportanceCell.value = TextCellValue('A');
    afternoonImportanceCell.cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    currentRow += afternoonTimeRanges.length;

    // 勤勉时间（第14行）
    final diligenceRow = 14;
    sheet.cell(CellIndex.indexByString('A$diligenceRow')).value = TextCellValue(
      serialNumber.toString(),
    );
    sheet.cell(CellIndex.indexByString('B$diligenceRow')).value = TextCellValue(
      diligenceTimeRange,
    );
    sheet.cell(CellIndex.indexByString('C$diligenceRow')).value = TextCellValue(
      'A',
    );

    // 合并"具体内容"列（D5:D14）和"输出成果"列（E5:E14）
    sheet.merge(CellIndex.indexByString('D5'), CellIndex.indexByString('D14'));
    sheet.merge(CellIndex.indexByString('E5'), CellIndex.indexByString('E14'));

    // 填充具体内容和输出成果（从report.todayWork中取数据）
    if (report.todayWork.isNotEmpty) {
      final firstWorkItem = report.todayWork[0];
      final contentCell = sheet.cell(CellIndex.indexByString('D5'));
      contentCell.value = TextCellValue(firstWorkItem.content);
      contentCell.cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final outputCell = sheet.cell(CellIndex.indexByString('E5'));
      outputCell.value = TextCellValue(firstWorkItem.output);
      outputCell.cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    // 设置所有数据行样式（第5-14行）
    for (int row = 5; row <= 14; row++) {
      for (int col = 0; col < 6; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row - 1),
        );
        cell.cellStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }
    }

    // 4. 明日工作计划（PLAN: 计划）模块
    // 4.1 模块标题：合并 A15 到 F15
    final tomorrowPlanTitleRow = 15;
    final tomorrowPlanTitleCell = sheet.cell(
      CellIndex.indexByString('A$tomorrowPlanTitleRow'),
    );
    tomorrowPlanTitleCell.value = TextCellValue('明日工作计划 (PLAN: 计划)');
    tomorrowPlanTitleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    sheet.merge(
      CellIndex.indexByString('A$tomorrowPlanTitleRow'),
      CellIndex.indexByString('F$tomorrowPlanTitleRow'),
    );

    // 4.2 表头行：第16行
    final tomorrowPlanHeaderRow = 16;
    final tomorrowPlanHeaders = ['序号', '工作时间', '重要程度', '具体内容', '输出成果', ''];
    for (int i = 0; i < tomorrowPlanHeaders.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: i,
          rowIndex: tomorrowPlanHeaderRow - 1,
        ),
      );
      cell.value = TextCellValue(tomorrowPlanHeaders[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    // 4.3 数据行：第17-25行，共9行
    // 上午4个时间段
    final tomorrowMorningTimeRanges = [
      '8:30-9:30',
      '9:30-10:30',
      '10:30-11:30',
      '11:30-12:00',
    ];

    // 下午5个时间段
    final tomorrowAfternoonTimeRanges = [
      '13:30-14:30',
      '14:30-15:30',
      '15:30-16:30',
      '16:30-17:30',
      '17:30-18:00',
    ];

    // 填充明日工作计划数据
    int tomorrowCurrentRow = 17;
    int tomorrowSerialNumber = 1;

    // 上午4个时间段
    for (int i = 0; i < tomorrowMorningTimeRanges.length; i++) {
      final row = tomorrowCurrentRow + i;
      // 序号
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        tomorrowSerialNumber.toString(),
      );
      tomorrowSerialNumber++;
      // 工作时间
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
        tomorrowMorningTimeRanges[i],
      );
    }

    // 合并上午的"重要程度"单元格（C17:C20）
    sheet.merge(CellIndex.indexByString('C17'), CellIndex.indexByString('C20'));
    final tomorrowMorningImportanceCell = sheet.cell(
      CellIndex.indexByString('C17'),
    );
    tomorrowMorningImportanceCell.value = TextCellValue('A');
    tomorrowMorningImportanceCell.cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    tomorrowCurrentRow += tomorrowMorningTimeRanges.length;

    // 下午5个时间段
    for (int i = 0; i < tomorrowAfternoonTimeRanges.length; i++) {
      final row = tomorrowCurrentRow + i;
      // 序号
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        tomorrowSerialNumber.toString(),
      );
      tomorrowSerialNumber++;
      // 工作时间
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
        tomorrowAfternoonTimeRanges[i],
      );
    }

    // 合并下午的"重要程度"单元格（C21:C25）
    sheet.merge(CellIndex.indexByString('C21'), CellIndex.indexByString('C25'));
    final tomorrowAfternoonImportanceCell = sheet.cell(
      CellIndex.indexByString('C21'),
    );
    tomorrowAfternoonImportanceCell.value = TextCellValue('A');
    tomorrowAfternoonImportanceCell.cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // 合并"具体内容"列（D17:D25）
    sheet.merge(CellIndex.indexByString('D17'), CellIndex.indexByString('D25'));

    // 填充具体内容（从report.tomorrowPlan中取数据）
    if (report.tomorrowPlan.isNotEmpty) {
      final firstPlanItem = report.tomorrowPlan[0];
      final contentCell = sheet.cell(CellIndex.indexByString('D17'));
      contentCell.value = TextCellValue(firstPlanItem.content);
      contentCell.cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    // 设置所有数据行样式（第17-25行）
    for (int row = 17; row <= 25; row++) {
      for (int col = 0; col < 6; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row - 1),
        );
        cell.cellStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }
    }

    // 5. 今日未完成工作（CHECK: 检查）模块
    // 5.1 模块标题：合并 A26 到 F26
    final unfinishedWorkTitleRow = 26;
    final unfinishedWorkTitleCell = sheet.cell(
      CellIndex.indexByString('A$unfinishedWorkTitleRow'),
    );
    unfinishedWorkTitleCell.value = TextCellValue('今日未完成工作 (CHECK: 检查)');
    unfinishedWorkTitleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    sheet.merge(
      CellIndex.indexByString('A$unfinishedWorkTitleRow'),
      CellIndex.indexByString('F$unfinishedWorkTitleRow'),
    );

    // 5.2 表头行：第27行
    final unfinishedWorkHeaderRow = 27;
    final unfinishedWorkHeaders = ['序号', '工作内容', '未完成原因', '改进措施', '今日自评', ''];
    for (int i = 0; i < unfinishedWorkHeaders.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: i,
          rowIndex: unfinishedWorkHeaderRow - 1,
        ),
      );
      cell.value = TextCellValue(unfinishedWorkHeaders[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    // 5.3 数据行：第28-30行，共3行
    // 预留3行空数据行
    for (int i = 0; i < 3; i++) {
      final row = 28 + i;
      // 序号
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        (i + 1).toString(),
      );

      // 如果存在未完成工作数据，则填充
      if (i < report.unfinishedWork.length) {
        final unfinishedItem = report.unfinishedWork[i];
        sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
          unfinishedItem.workContent,
        );
        sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(
          unfinishedItem.reason,
        );
        sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(
          unfinishedItem.improvement,
        );
      }
    }

    // 合并"今日自评"列（E28:E30）
    sheet.merge(CellIndex.indexByString('E28'), CellIndex.indexByString('E30'));
    final selfEvaluationCell = sheet.cell(CellIndex.indexByString('E28'));
    selfEvaluationCell.value = TextCellValue('${report.selfEvaluation}');
    selfEvaluationCell.cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // 设置所有数据行样式（第28-30行）
    for (int row = 28; row <= 30; row++) {
      for (int col = 0; col < 6; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row - 1),
        );
        cell.cellStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }
    }

    // 6. 今日总结 + 填写说明 + 备注
    // 6.1 今日总结标题：合并 A31 到 F31
    final summaryTitleRow = 31;
    final summaryTitleCell = sheet.cell(
      CellIndex.indexByString('A$summaryTitleRow'),
    );
    summaryTitleCell.value = TextCellValue('今日总结');
    summaryTitleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    sheet.merge(
      CellIndex.indexByString('A$summaryTitleRow'),
      CellIndex.indexByString('F$summaryTitleRow'),
    );

    // 6.2 今日总结内容：合并 A32 到 F32
    final summaryContentRow = 32;
    final summaryContentCell = sheet.cell(
      CellIndex.indexByString('A$summaryContentRow'),
    );
    summaryContentCell.value = TextCellValue(report.summary);
    summaryContentCell.cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    sheet.merge(
      CellIndex.indexByString('A$summaryContentRow'),
      CellIndex.indexByString('F$summaryContentRow'),
    );

    // 6.3 填写说明标题：合并 A33 到 F33
    final instructionsTitleRow = 33;
    final instructionsTitleCell = sheet.cell(
      CellIndex.indexByString('A$instructionsTitleRow'),
    );
    instructionsTitleCell.value = TextCellValue('填写说明:');
    instructionsTitleCell.cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    sheet.merge(
      CellIndex.indexByString('A$instructionsTitleRow'),
      CellIndex.indexByString('F$instructionsTitleRow'),
    );

    // 6.4 填写说明内容：第34-38行，共5条
    final instructions = [
      '1. 工作时间：上午8:30-12:00，下午13:30-18:00，勤勉时间18:30-',
      '2. 重要程度：A-非常重要，B-重要，C-一般，D-次要',
      '3. 具体内容：填写具体工作内容，要求详细、具体',
      '4. 输出成果：填写工作成果，如文档、代码、报告等',
      '5. 今日自评：根据工作完成情况进行评分（0-100分）',
    ];

    for (int i = 0; i < instructions.length; i++) {
      final row = 34 + i;
      final cell = sheet.cell(CellIndex.indexByString('A$row'));
      cell.value = TextCellValue(instructions[i]);
      cell.cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );
      sheet.merge(
        CellIndex.indexByString('A$row'),
        CellIndex.indexByString('F$row'),
      );
    }

    // 6.5 备注标题：合并 A39 到 F39
    final remarksTitleRow = 39;
    final remarksTitleCell = sheet.cell(
      CellIndex.indexByString('A$remarksTitleRow'),
    );
    remarksTitleCell.value = TextCellValue('备注:');
    remarksTitleCell.cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    sheet.merge(
      CellIndex.indexByString('A$remarksTitleRow'),
      CellIndex.indexByString('F$remarksTitleRow'),
    );

    // 6.6 备注内容：第40-41行，共2条
    final remarks = ['1. 请如实填写工作内容，确保数据准确无误', '2. 每日工作完成后及时提交，便于统计和管理'];

    for (int i = 0; i < remarks.length; i++) {
      final row = 40 + i;
      final cell = sheet.cell(CellIndex.indexByString('A$row'));
      cell.value = TextCellValue(remarks[i]);
      cell.cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );
      sheet.merge(
        CellIndex.indexByString('A$row'),
        CellIndex.indexByString('F$row'),
      );
    }

    // 7. 应用边框样式到所有数据单元格
    _applyBorders(sheet);

    // 8. 自动调整列宽，限制最大列宽为50
    _autoSizeColumns(sheet, 41);

    // 9. 生成Excel文件
    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }

  static void _applyBorders(Sheet sheet) {
    try {
      // 尝试应用边框到所有数据单元格（第1-41行，第A-F列）
      for (int row = 0; row < 41; row++) {
        for (int col = 0; col < 6; col++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
          );
          // 尝试创建新样式，包含边框
          cell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            verticalAlign: VerticalAlign.Center,
          );
        }
      }
    } catch (e) {
      // 忽略边框设置错误，继续生成Excel
    }
  }

  static void _autoSizeColumns(Sheet sheet, int maxRow) {
    // 计算每列的最大文本长度
    final maxCol = 5; // 最大列索引（A-F列）
    final colMaxLength = List<int>.filled(maxCol + 1, 0);

    for (int row = 0; row < maxRow; row++) {
      for (int col = 0; col <= maxCol; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        final value = cell.value;
        if (value != null) {
          final text = value.toString();
          // 计算文本长度（考虑换行符）
          final lines = text.split('\n');
          for (final line in lines) {
            final length = line.length;
            if (length > colMaxLength[col]) {
              colMaxLength[col] = length;
            }
          }
        }
      }
    }

    // 根据最大长度设置列宽，限制最大列宽为50
    for (int col = 0; col <= maxCol; col++) {
      final maxLength = colMaxLength[col];
      if (maxLength > 0) {
        // 根据字符数设置宽度，每个字符大约1.2个单位
        double width = maxLength * 1.2 + 2.0;
        // 限制最大列宽为50
        if (width > 50.0) {
          width = 50.0;
        }
        sheet.setColumnWidth(col, width);
      }
    }
  }
}
