import 'package:material_ui/material_ui.dart';

class PhoneWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const PhoneWidth({super.key, required this.child, this.maxWidth = 520});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}