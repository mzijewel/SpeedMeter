import 'package:flutter/material.dart';

/// Shows a styled dialog with a single text field for naming a trip.
///
/// Returns the trimmed title, or `null` if the user cancelled. An empty
/// submission resolves to an empty string so callers can choose to treat it
/// as "no title".
Future<String?> showTitleDialog(BuildContext context, {String? initial}) {
  final controller = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      title: const Text(
        'Name this trip',
        style: TextStyle(color: Colors.white),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(color: Colors.white),
        cursorColor: const Color(0xFF00E676),
        decoration: const InputDecoration(
          hintText: 'e.g. Morning commute',
          hintStyle: TextStyle(color: Color(0xFF555566)),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF2D2D44)),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF00E676)),
          ),
        ),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL',
              style: TextStyle(color: Color(0xFF9E9E9E))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('SAVE',
              style: TextStyle(color: Color(0xFF00E676))),
        ),
      ],
    ),
  );
}
