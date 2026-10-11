import 'package:logging/logging.dart';

import 'tool/tool.dart';
import 'tool/tool_error.dart';
import 'tool/tool_instance.dart';
import 'tool/tool_resolver.dart';

abstract final class Tools {
  static Tool get git => Tool(
    name: 'Git',
    defaultResolver: CliVersionResolver(
      wrappedResolver: PathToolResolver(toolName: 'Git', executableName: 'git'),
    ),
  );

  static Tool get cmake => Tool(
    name: 'CMake',
    defaultResolver: CliVersionResolver(
      wrappedResolver: PathToolResolver(
        toolName: 'CMake',
        executableName: 'cmake',
      ),
    ),
  );
}

extension ToolX on Tool {
  Future<ToolInstance> resolve({required Logger? logger}) async {
    final context = ToolResolvingContext(logger: logger);
    final resolved = (await defaultResolver!.resolve(
      context,
    )).where((i) => i.tool == this).toList()..sort();
    final result = resolved.firstOrNull;
    if (result == null) {
      final errorMessage = '$name is not found';
      logger?.severe(errorMessage);
      throw ToolError(errorMessage);
    }
    return result;
  }
}
