import 'package:flutter/material.dart';

class LargeCard extends StatelessWidget {
  const LargeCard({
    super.key,
    required this.firstRow,
    required this.secondRow,
    this.thirdRow,
    required this.sourceString,
  });

  final String firstRow;
  final String secondRow;
  final Widget? thirdRow;
  final String sourceString;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Card(
            margin: const EdgeInsets.all(0),
            elevation: 100,
            clipBehavior: Clip.antiAliasWithSaveLayer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.width / 2,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            firstRow,
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width / (firstRow.length > 20 ? 20 : firstRow.length),
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            secondRow,
                            style: const TextStyle(fontSize: kDefaultFontSize * 1.2),
                          ),
                        ),
                        if (thirdRow != null) thirdRow!,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Quelle: ${() {
                var uri = Uri.tryParse('http$sourceString');
                if (uri == null) return 'http$sourceString';
                return uri.host;
              }()}',
              style: const TextStyle(fontSize: kDefaultFontSize * 0.7),
            ),
          ],
        ),
      ],
    );
  }
}
