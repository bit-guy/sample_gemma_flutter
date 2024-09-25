import 'package:flutter/material.dart';
import 'dart:async';
import 'gemma.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemma Chat App',
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
  late GemmaModel _model;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  var _tokenStreamController = StreamController<String>();
  bool _isGenerating = false;
  String _currentResponse = '';
  String _selectedModel = list.first;

  @override
  void initState() {
    super.initState();
    _initializeModel();
    _tokenStreamController.stream.listen((token) {
      setState(() {
        _currentResponse += token;
        _messages.last.text = _currentResponse;
      });
      _scrollToBottom();
    });
  }

  void _initializeModel() {
    _model = GemmaModel(_selectedModel);
  }

  @override
  void dispose() {
    _model.cleanupModel();
    _model.dispose();
    _textController.dispose();
    _tokenStreamController.close();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleModelChange(String? newModel) {
    if (newModel != null && newModel != _selectedModel) {
      setState(() {
        _selectedModel = newModel;
        _model.cleanupModel();
        _model.dispose();
        _initializeModel();
      });
    }
  }

  void _handleSubmitted(String text) {
    _textController.clear();
    ChatMessage message = ChatMessage(
      text: text,
      isUser: true,
      model: _selectedModel,
    );
    setState(() {
      _messages.add(message);
      _isGenerating = true;
    });
    _currentResponse = '';
    _messages.add(ChatMessage(text: '', isUser: false, model: _selectedModel));
    _generateResponse(text);
  }

  Future<void> _generateResponse(String prompt) async {
    try {
      await _model.generateResponseAsync(prompt, (token) {
        _tokenStreamController.add(token);
      });
    } catch (e) {
      print("Error generating response: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        shape: const Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
        title: Center(
          child: PlaygroundTitle(
            selectedModel: _selectedModel,
            onModelChanged: _handleModelChange,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) => _messages[index],
            ),
          ),
          Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: _isGenerating ? null : _handleSubmitted,
                decoration:
                    InputDecoration.collapsed(hintText: "Send a message"),
                enabled: !_isGenerating,
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: Icon(Icons.send),
                onPressed: _isGenerating
                    ? null
                    : () => _handleSubmitted(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  String text;
  final bool isUser;
  final String model;

  ChatMessage({required this.text, required this.isUser, this.model = 'Gemma'});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              child: Text(isUser ? 'U' : 'G'),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isUser ? 'User' : model,
                    style: Theme.of(context).textTheme.titleMedium),
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

const List<String> list = <String>[
  'gemma-2b-sfp',
  'recurrentgemma-2b-it-sfp-cpp',
];

class PlaygroundTitle extends StatelessWidget {
  final String selectedModel;
  final Function(String?) onModelChanged;

  const PlaygroundTitle({
    Key? key,
    required this.selectedModel,
    required this.onModelChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        alignment: Alignment.center,
        value: selectedModel,
        icon: const Icon(Icons.arrow_drop_down),
        onChanged: onModelChanged,
        items: list.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Center(child: Text(value)),
          );
        }).toList(),
      ),
    );
  }
}
