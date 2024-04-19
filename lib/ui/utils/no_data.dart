import 'package:flutter/material.dart';

class NoDataWidget extends StatelessWidget {
  const NoDataWidget({
    super.key,
    required this.text,
    this.button,
    this.enableAppBar = false,
    this.appBarText,
  });

  final String text;
  final Widget? button;
  final bool enableAppBar;
  final String? appBarText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: enableAppBar ? AppBar(title: Text(appBarText ?? '')) : null,
      body: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/no_data.png',
                height: MediaQuery.of(context).size.width / 2,
                width: MediaQuery.of(context).size.width / 2,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: MediaQuery.of(context).size.width / 1.5,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                ),
              ),
              if (button != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: button!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
