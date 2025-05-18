import 'package:flutter/material.dart';

class LeaveButton extends StatelessWidget {
  final VoidCallback? onPressed;

  final String? tooltip;

  const LeaveButton({
    super.key,
    required this.onPressed,

    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.identity()..scale(onPressed != null ? 1.0 : 0.95),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null ? Colors.redAccent : Colors.grey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: onPressed != null ? 4 : 0,
        ),
        child: Row(
          children: [
            Icon(
              Icons.exit_to_app,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 4,),
            Text("Leave",
              style: TextStyle(
                fontFamily: "Poppins",
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );

    return tooltip != null && tooltip!.isNotEmpty
        ? Tooltip(
      message: tooltip!,
      child: button,
    )
        : button;
  }
}