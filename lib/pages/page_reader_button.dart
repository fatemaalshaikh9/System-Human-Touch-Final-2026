import 'package:flutter/material.dart';
import 'app_tts.dart';

class PageReaderButton extends StatefulWidget {
  final String pageText;

  const PageReaderButton({
    super.key,
    required this.pageText,
  });

  @override
  State<PageReaderButton> createState() => _PageReaderButtonState();
}

class _PageReaderButtonState extends State<PageReaderButton> {
  bool _isSpeaking = false;

  Future<void> _toggleReading() async {
    if (_isSpeaking) {
      await AppTts.stop();

      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    } else {
      await AppTts.speak(widget.pageText);

      if (mounted) {
        setState(() {
          _isSpeaking = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _toggleReading,
      backgroundColor: Theme.of(context).primaryColor,
      child: Icon(
        _isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
        color: Colors.white,
      ),
    );
  }
}
