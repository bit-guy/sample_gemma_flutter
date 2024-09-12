import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'gemma.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemma Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gemma Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) => _messages[index],
            ),
          ),
          if (_isLoading) LinearProgressIndicator(),
          Divider(height: 1.0),
          _buildTextComposer(),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Flexible(
            child: TextField(
              controller: _textController,
              onSubmitted: _handleSubmitted,
              decoration: InputDecoration.collapsed(hintText: "Send a message"),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: () => _handleSubmitted(_textController.text),
          ),
        ],
      ),
    );
  }

  void _handleSubmitted(String text) async {
    if (text.isEmpty) return;
    _textController.clear();
    ChatMessage message = ChatMessage(
      text: text,
      isUser: true,
    );
    setState(() {
      _messages.add(message);
      _isLoading = true;
    });

    await _getGemmaResponse(text);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _getGemmaResponse(String input) async {
    try {
      var libraryPath = path.join(Directory.current.path, 'src', 'gemma.exe');

      final process = await Process.start(libraryPath, [
        '--tokenizer',
        path.join(
            Directory.current.path, 'src', 'gemma-2b-sfp', 'tokenizer.spm'),
        '--weights',
        path.join(
            Directory.current.path, 'src', 'gemma-2b-sfp', '2b-pt-sfp.sbs'),
        '--weight_type',
        'sfp',
        '--model',
        '2b-pt',
        '--verbosity',
        '0',
        '--max_generated_tokens',
        '8'
      ]);

      process.stdin.writeln(input);
      await process.stdin.close();

      String response = '';
      process.stdout.transform(utf8.decoder).listen((data) {
        response += data;
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        print('Error from executable: $data');
      });

      await process.exitCode;

      setState(() {
        _messages.add(ChatMessage(
          text: response.trim(),
          isUser: false,
        ));
      });
    } catch (e) {
      print('Error: $e');
      setState(() {
        _messages.add(ChatMessage(
          text: "Error: $e",
          isUser: false,
        ));
      });
    }
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(child: Text(isUser ? "You" : "AI")),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isUser ? "You" : "Gemma",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  margin: EdgeInsets.only(top: 5.0),
                  child: Text(text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
