import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isReadOnly;
  final Widget? suffixIcon;
  final Color? fillColor;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.isReadOnly,
    this.suffixIcon,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: isReadOnly,
      obscureText: hint == "Password" || hint == "Confirm Password",
      cursorColor: Theme.of(context).primaryColor,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey),
        filled: true,
        fillColor: fillColor,
        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}