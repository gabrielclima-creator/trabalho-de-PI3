import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const CristalApp());
}

class CristalApp extends StatelessWidget {
  const CristalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cristal - Garçonete Digital',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.orange,
        colorScheme: const ColorScheme.dark(
          primary: Colors.orange,
          secondary: Colors.blueAccent,
          surface: Color(0xFF1E1E1E),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

// Modelo do Lanche
class MenuItem {
  final String name;
  final double price;
  final String description;
  final String imagePath;

  MenuItem({
    required this.name,
    required this.price,
    required this.description,
    required this.imagePath,
  });
}

// Modelo da Mensagem de Chat
class ChatMessage {
  final String sender;
  final String text;
  final bool isOptions;

  ChatMessage({
    required this.sender,
    required this.text,
    this.isOptions = false,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();

  // 🔑 SUA CHAVE GERADA NO CONSOLE DA GROQ
  static const String _groqApiKey = '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';

  final List<Map<String, String>> _chatHistory = [];
  bool _isLoading = false;

  final List<MenuItem> _menuItems = [
    MenuItem(
      name: 'Burguer',
      price: 25.00,
      description: 'Hambúrguer e queijo',
      imagePath: 'assets/carne1.png',
    ),
    MenuItem(
      name: 'Salada',
      price: 28.00,
      description: 'Hambúrguer, alface, tomate e queijo',
      imagePath: 'assets/carne2.png',
    ),
    MenuItem(
      name: 'Bacon',
      price: 31.00,
      description: 'Hambúrguer, alface, tomate, bacon e queijo',
      imagePath: 'assets/carne3.png',
    ),
    MenuItem(
      name: 'Tudo',
      price: 38.00,
      description:
          'Hambúrguer, alface, tomate, ovo, bacon, calabresa, presunto, milho e queijo',
      imagePath: 'assets/carne4.png',
    ),
    MenuItem(
      name: 'Frango Salada',
      price: 26.00,
      description: 'Frango, alface, tomate e queijo',
      imagePath: 'assets/frango2.png',
    ),
    MenuItem(
      name: 'Frango Bacon',
      price: 30.00,
      description: 'Frango, alface, tomate, bacon e queijo',
      imagePath: 'assets/frango3.png',
    ),
  ];

  @override
  void initState() {
    super.initState();

    final menuDescription = _menuItems
        .map((item) =>
            '- ${item.name}: R\$ ${item.price.toStringAsFixed(2)} (${item.description})')
        .join('\n');

    final systemPrompt = '''
Você é a Cristal, uma garçonete virtual muito educada, ágil e prestativa de uma lanchonete.
Seu objetivo é atender o cliente, anotar o pedido, permitir trocas ou remoções e informar o valor total.

Cardápio Disponível:
$menuDescription

Instruções de atendimento:
- Responda de forma natural, amigável e concisa.
- A taxa de entrega fixa é de R\$ 5,00. Caso o cliente peça para retirar no local/balcão, não cobre taxa de entrega.
- Ajude o cliente a somar os itens do pedido e informe os valores de forma clara.
- Se o cliente quiser trocar ou remover algo, confirme a alteração no pedido com simpatia.
''';

    _chatHistory.add({
      "role": "system",
      "content": systemPrompt,
    });

    _messages.add(
      ChatMessage(
        sender: 'cristal',
        text: 'Boa noite! Meu nome é Cristal. O que deseja do nosso cardápio hoje?',
        isOptions: true,
      ),
    );
  }

  void _addFromCard(MenuItem item) {
    _handleSubmittedText('Quero um ${item.name}');
  }

  Future<void> _handleSubmittedText(String text) async {
    final rawQuery = text.trim();
    if (rawQuery.isEmpty || _isLoading) return;

    final formattedKey = _groqApiKey.trim();

    if (formattedKey.isEmpty || !formattedKey.startsWith('gsk_')) {
      setState(() {
        _messages.add(
          ChatMessage(
            sender: 'cristal',
            text: '⚠️ Atenção: A chave Groq informada é inválida!',
          ),
        );
      });
      return;
    }

    _textController.clear();

    setState(() {
      _messages.add(ChatMessage(sender: 'user', text: rawQuery));
      _isLoading = true;
    });

    _chatHistory.add({
      "role": "user",
      "content": rawQuery,
    });

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $formattedKey',
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": _chatHistory,
          "temperature": 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final replyText = data['choices'][0]['message']['content'];

        _chatHistory.add({
          "role": "assistant",
          "content": replyText,
        });

        setState(() {
          _messages.add(ChatMessage(sender: 'cristal', text: replyText));
        });
      } else {
        String detailMessage = '';
        try {
          final errBody = jsonDecode(response.body);
          detailMessage = errBody['error']?['message'] ?? response.body;
        } catch (_) {
          detailMessage = response.body;
        }

        debugPrint('Erro Groq (${response.statusCode}): $detailMessage');

        setState(() {
          _messages.add(
            ChatMessage(
              sender: 'cristal',
              text: 'Erro ${response.statusCode}: $detailMessage',
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Exceção: $e');
      setState(() {
        _messages.add(
          ChatMessage(
            sender: 'cristal',
            text: 'Erro de conexão: $e',
          ),
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Cristal - Atendimento Groq IA',
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Atendimento Ultra-Rápido Ativo',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.orange),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                bool isCristal = msg.sender == 'cristal';

                return Column(
                  crossAxisAlignment: isCristal
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 5.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: isCristal
                            ? const Color(0xFF2C2C2C)
                            : Colors.blueAccent,
                        borderRadius: BorderRadius.circular(12.0),
                        border: isCristal
                            ? Border.all(color: Colors.orange, width: 1)
                            : null,
                      ),
                      child: Text(
                        msg.text,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16.0),
                      ),
                    ),
                    if (msg.isOptions && index == 0)
                      Column(
                        children: _menuItems.map((item) {
                          return Card(
                            color: const Color(0xFF1E1E1E),
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(
                                  color: Colors.orange, width: 0.8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 6.0),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.asset(
                                  item.imagePath,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.fastfood,
                                          color: Colors.orange, size: 40),
                                ),
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${item.description}\nR\$ ${item.price.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                ),
                                onPressed: () => _addFromCard(item),
                                child: const Text('Adicionar',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: CircularProgressIndicator(color: Colors.orange),
            ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: const Color(0xFF1E1E1E),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Digite seu pedido, trocas ou dúvidas...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF2C2C2C),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide:
                            const BorderSide(color: Colors.orange, width: 1.5),
                      ),
                    ),
                    onSubmitted: _handleSubmittedText,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.orange),
                  onPressed: () => _handleSubmittedText(_textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
