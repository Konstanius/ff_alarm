abstract class Utils {
  static String getAppStack(int startingDepth) {
    String stack = '';
    StackTrace trace = StackTrace.current;

    List<String> lines = trace.toString().split('\n');
    for (int i = startingDepth; i < lines.length; i++) {
      if (lines[i].length < 4) continue;
      String line = lines[i].substring(3).trim();
      if (line.contains('ff_alarm')) {
        if (stack.isNotEmpty) stack += ' <- ';
        stack += line;
      }
    }
    return stack;
  }
}
