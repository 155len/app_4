import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/blood_glucose.dart';
import '../repositories/glucose_repository.dart';
import '../../domain/entities/time_period.dart';

/// 数据导出服务
class ExportService {
  /// 导出为 CSV
  static Future<String> exportToCsv({
    DateTime? start,
    DateTime? end,
  }) async {
    final repo = GlucoseRepository();
    final records = start != null && end != null
        ? repo.getByRange(start, end)
        : repo.getAll();

    final buffer = StringBuffer();
    // CSV 表头
    buffer.writeln('ID，日期，时间，血糖值 (mmol/L),时段，餐后，备注');

    for (final record in records) {
      buffer.writeln(
        '${record.id},'
        '${DateFormat('yyyy-MM-dd').format(record.timestamp)},'
        '${DateFormat('HH:mm').format(record.timestamp)},'
        '${record.value},'
        '${getPeriodName(record.period)},'
        '${record.isPostMeal ? '是' : '否'},'
        '"${record.note ?? ''}"',
      );
    }

    // 保存到文件
    final dir = await getApplicationDocumentsDirectory();
    final csvDir = Directory('${dir.path}/exports');
    if (!await csvDir.exists()) {
      await csvDir.create(recursive: true);
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${csvDir.path}/glucose_$timestamp.csv';
    final file = File(filePath);
    await file.writeAsString(buffer.toString());

    return filePath;
  }

  /// 导出为 PDF 报告
  static Future<String> exportToPdf({
    DateTime? start,
    DateTime? end,
  }) async {
    final repo = GlucoseRepository();
    final records = start != null && end != null
        ? repo.getByRange(start, end)
        : repo.getAll();

    final stats = repo.getStatistics(start: start, end: end);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            _buildHeader(context),
            pw.SizedBox(height: 20),
            _buildSummary(context, stats, records, start, end),
            pw.SizedBox(height: 20),
            _buildDataTable(context, records),
          ];
        },
      ),
    );

    // 保存到文件
    final dir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${dir.path}/exports');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${pdfDir.path}/glucose_report_$timestamp.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }

  /// 构建 PDF 头部
  static pw.Widget _buildHeader(pw.Context context) {
    return pw.Header(
      level: 0,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '血糖监测报告',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            '生成日期：${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// 构建摘要信息
  static pw.Widget _buildSummary(
    pw.Context context,
    Map<String, dynamic> stats,
    List<BloodGlucoseRecord> records,
    DateTime? start,
    DateTime? end,
  ) {
    String dateRange;
    if (start != null && end != null) {
      dateRange = '${DateFormat('yyyy-MM-dd').format(start)} 至 ${DateFormat('yyyy-MM-dd').format(end)}';
    } else {
      dateRange = '全部记录';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '数据概览',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text('统计范围：$dateRange'),
          pw.Text('记录总数：${stats['count']} 次'),
          if (stats['average'] != null)
            pw.Text('平均血糖：${(stats['average'] as num).toStringAsFixed(1)} mmol/L'),
          if (stats['min'] != null)
            pw.Text('最低血糖：${stats['min']} mmol/L'),
          if (stats['max'] != null)
            pw.Text('最高血糖：${stats['max']} mmol/L'),
          if (stats['fastingAverage'] != null)
            pw.Text('空腹平均：${(stats['fastingAverage'] as num).toStringAsFixed(1)} mmol/L'),
          if (stats['postMealAverage'] != null)
            pw.Text('餐后平均：${(stats['postMealAverage'] as num).toStringAsFixed(1)} mmol/L'),
        ],
      ),
    );
  }

  /// 构建数据表格
  static pw.Widget _buildDataTable(
    pw.Context context,
    List<BloodGlucoseRecord> records,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '详细记录',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(1),
            4: pw.FlexColumnWidth(1),
          },
          children: [
            // 表头
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('日期/时间', isHeader: true),
                _buildTableCell('血糖值', isHeader: true),
                _buildTableCell('时段', isHeader: true),
                _buildTableCell('类型', isHeader: true),
                _buildTableCell('备注', isHeader: true),
              ],
            ),
            // 数据行
            ...records.map((record) => pw.TableRow(
              children: [
                _buildTableCell(
                  DateFormat('MM-dd HH:mm').format(record.timestamp),
                ),
                _buildTableCell('${record.value}'),
                _buildTableCell(getPeriodName(record.period, short: true)),
                _buildTableCell(record.isPostMeal ? '餐后' : '空腹/餐前'),
                _buildTableCell(record.note ?? ''),
              ],
            )),
          ],
        ),
      ],
    );
  }

  /// 构建表格单元格
  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }
}
