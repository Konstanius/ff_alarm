import 'package:ff_alarm/globals.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher_string.dart';

Future<dynamic> generalDialog({
  required Color color,
  required String title,
  required Widget content,
  required List<DialogActionButton> actions,
}) {
  return showDialog(
    barrierColor: Theme.of(Globals.context!).colorScheme.background.withOpacity(0.5),
    useSafeArea: true,
    barrierDismissible: true,
    context: Globals.context!,
    builder: (BuildContext context) {
      return AlertDialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: const EdgeInsets.only(top: 15, left: 15, right: 15, bottom: 5),
        backgroundColor: Theme.of(Globals.context!).scaffoldBackgroundColor,
        title: Text(title, style: Theme.of(Globals.context!).textTheme.titleLarge!.copyWith(color: color)),
        content: SingleChildScrollView(child: content),
        actions: [
          for (DialogActionButton action in actions)
            TextButton(
              onPressed: () {
                action.onPressed();
              },
              child: Text(action.text, style: TextStyle(color: color)),
            ),
        ],
      );
    },
  );
}

class DialogActionButton {
  String text;
  Function onPressed;

  DialogActionButton({required this.text, required this.onPressed});
}

Future<void> discardDialog(BuildContext context) async {
  await generalDialog(
    color: Colors.blue,
    title: "Änderungen verwerfen",
    content: const Text("Möchtest du deine Änderungen verwerfen?"),
    actions: [
      DialogActionButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        text: "Abbrechen",
      ),
      DialogActionButton(
        onPressed: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
        text: "Verwerfen",
      ),
    ],
  );
}

Future<void> aboutDialog() async {
  return generalDialog(
    color: Colors.blue,
    title: 'Wie funktioniert das?',
    content: Column(
      children: [
        Text(
          'FF Alarm ist ein Open-Source Projekt aus Jena, entwickelt von Konstantin Dubnack.',
          style: Theme.of(Globals.context!).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Jede BOS-Leitstelle kann kostenlos an dem Projekt teilnehmen. Dazu werden alle relevanten Daten sicher und datenschutzkonform auf dem Server der '
          'jeweiligen Leitstelle gespeichert.',
          style: Theme.of(Globals.context!).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Der Fokus des Projekts liegt sowohl darauf, jeder Einsatzkraft eine optimale und sichere Alarmierungsapp mit allen Features zu bieten, als auch den Kommunen und '
          'Leitstellen Geld und Ressourcen zu sparen, statt sonstige aufwändige Technik aufbringen zu müssen.',
          style: Theme.of(Globals.context!).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Das Projekt wurde im April 2024 gestartet und wird dauerhaft weiter entwickelt. Der Source Code ist öffentlich einsehbar und Änderungsvorschläge '
          '/ Fehlermeldungen / Risikoanalysen können jederzeit auf GitHub mitgeteilt werden. Links dazu findest du unten.',
          style: Theme.of(Globals.context!).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Die FF Alarm App kommuniziert mit allen Servern, in denen du dich registriert hast und als Daten-Quelle hinzugefügt hast.',
          style: Theme.of(Globals.context!).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Das erlaubt den Einsatzkräften, in mehreren Wachen aus verschiedenen BOS-Leitstellenbereichen die App gleichzeitig zu nutzen, ohne dass die Server '
          'der Leitstellen aufeinander abgestimmt werden müssen oder Daten ausgetauscht werden.',
          style: Theme.of(Globals.context!).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextButton(
              onPressed: () {
                launchUrlString('https://github.com/Konstanius/FF-Alarm');
              },
              child: const Text('GitHub Repositories'),
            ),
          ],
        ),
      ],
    ),
    actions: [
      DialogActionButton(
        onPressed: () {
          Navigator.pop(Globals.context!);
        },
        text: 'Schließen',
      ),
    ],
  );
}

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();

  static Future<String?> scanQR() async {
    return await Navigator.push(Globals.context!, MaterialPageRoute(builder: (context) => const QRScannerPage()));
  }
}

class _QRScannerPageState extends State<QRScannerPage> {
  bool enabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('QR-Code scannen'),
        backgroundColor: Theme.of(context).colorScheme.background,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (BarcodeCapture result) {
              if (result.barcodes.isEmpty) return;
              if (!enabled) return;
              enabled = false;
              Navigator.pop(context, result.barcodes.first.rawValue);
            },
          ),
          Center(
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width * 0.75, MediaQuery.of(context).size.width * 0.75),
              painter: const ScanOverlay(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class ScanOverlay extends CustomPainter {
  final Color color;

  const ScanOverlay(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..moveTo(0, size.height / 5)
      ..lineTo(0, 0)
      ..lineTo(size.width / 5, 0)
      ..moveTo(size.width, size.height / 5)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - size.width / 5, 0)
      ..moveTo(0, size.height - size.height / 5)
      ..lineTo(0, size.height)
      ..lineTo(size.width / 5, size.height)
      ..moveTo(size.width, size.height - size.height / 5)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - size.width / 5, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
