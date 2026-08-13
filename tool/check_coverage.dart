import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty || args.length > 2) {
    stderr.writeln(
      'Usage: dart run tool/check_coverage.dart <lcov.info> [minimum-percent]',
    );
    exitCode = 64;
    return;
  }

  final report = File(args.first);
  if (!report.existsSync()) {
    stderr.writeln('Coverage report not found: ${report.path}');
    exitCode = 66;
    return;
  }
  final minimum = args.length == 2 ? double.tryParse(args[1]) : 40.0;
  if (minimum == null || minimum < 0 || minimum > 100) {
    stderr.writeln('Minimum coverage must be a number between 0 and 100.');
    exitCode = 64;
    return;
  }

  var found = 0;
  var hit = 0;
  for (final line in report.readAsLinesSync()) {
    if (line.startsWith('LF:')) {
      found += int.tryParse(line.substring(3)) ?? 0;
    } else if (line.startsWith('LH:')) {
      hit += int.tryParse(line.substring(3)) ?? 0;
    }
  }
  if (found == 0) {
    stderr.writeln('Coverage report contains no executable lines.');
    exitCode = 65;
    return;
  }

  final percent = hit * 100 / found;
  stdout.writeln(
    'Line coverage: ${percent.toStringAsFixed(2)}% ($hit/$found), '
    'required: ${minimum.toStringAsFixed(2)}%',
  );
  if (percent + 0.000001 < minimum) exitCode = 1;
}
