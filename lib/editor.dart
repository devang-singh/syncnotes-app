import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Editor extends StatefulWidget {
  const Editor({super.key});

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  late WebSocketChannel _websocketChannel;
  final _textEditingController = TextEditingController();
  String? noteId;

  @override
  void initState() {
    super.initState();
    noteId = "e1040e6c-7196-4eb6-afd3-9d4d016b8a99";
    _websocketChannel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.0.4:8080/ws?note_id=e1040e6c-7196-4eb6-afd3-9d4d016b8a99'),
    );

    _websocketChannel.stream.listen((message) {
      final data = jsonDecode(message);
      if (data['type'] == "edit") {
        _textEditingController.text = data['content'];
        _textEditingController.selection = TextSelection.collapsed(
          offset: _textEditingController.text.length,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 44.0),
        child: TextField(
          controller: _textEditingController,
          onChanged: (value) {
            final message = {
              "type": "edit",
              "content": value,
              "note_id": noteId,
            };
            _websocketChannel.sink.add(jsonEncode(message));
          },
          maxLines: null,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _websocketChannel.sink.close();
    _textEditingController.dispose();
    super.dispose();
  }
}
