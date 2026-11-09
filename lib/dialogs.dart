import 'package:flutter/material.dart';

Future<String?> showTextInput(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
  bool multiline = false,
}) => showDialog<String>(
  context: context,
  builder: (context) => _TextInputDialog(
    title: title,
    hint: hint,
    initial: initial,
    multiline: multiline,
  ),
);

Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String okLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(okLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.hint,
    required this.initial,
    required this.multiline,
  });

  final String title;
  final String hint;
  final String initial;
  final bool multiline;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: widget.multiline ? 4 : 1,
        maxLines: widget.multiline ? 8 : 1,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: widget.multiline
            ? null
            : (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('확인'),
        ),
      ],
    );
  }
}
