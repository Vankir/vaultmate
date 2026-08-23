import 'package:flutter/material.dart';
import 'package:obsi/src/core/ai_assistant/ai_provider_config.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';

/// Lets the user choose which AI provider the assistant talks to, and
/// configure it: an API key for Gemini/ChatGPT (same as the AI assistant's
/// existing welcome-message flow), or an endpoint/key/model for a custom
/// OpenAI-compatible provider (e.g. DeepSeek, or a local model). The
/// built-in managed DeepSeek option needs no configuration at all (FR-006).
class AIProviderSettingsView extends StatefulWidget {
  const AIProviderSettingsView({super.key, required this.controller});

  static const routeName = '/ai_provider_settings';

  final SettingsController controller;

  @override
  State<AIProviderSettingsView> createState() => _AIProviderSettingsViewState();
}

class _AIProviderSettingsViewState extends State<AIProviderSettingsView> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _customApiKeyController;
  late final TextEditingController _modelController;

  @override
  void initState() {
    super.initState();
    final config = widget.controller.aiProviderConfig;
    _apiKeyController =
        TextEditingController(text: widget.controller.chatGptKey);
    _baseUrlController = TextEditingController(text: config.baseUrl);
    _customApiKeyController = TextEditingController(text: config.apiKey);
    _modelController = TextEditingController(text: config.model);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _customApiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.controller.aiProviderConfig;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Provider')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Choose which AI provider the assistant uses:'),
          const SizedBox(height: 8),
          ...AIProviderType.values.map((type) => RadioListTile<AIProviderType>(
                title: Text(_labelFor(type)),
                value: type,
                groupValue: config.providerType,
                onChanged: (value) {
                  if (value == null) return;
                  widget.controller.updateAIProviderType(value);
                  setState(() {});
                },
              )),
          const SizedBox(height: 16),
          if (config.providerType == AIProviderType.gemini ||
              config.providerType == AIProviderType.chatgpt)
            _buildApiKeyOnlyForm(),
          if (config.providerType == AIProviderType.customOpenAI)
            _buildCustomProviderForm(),
          if (config.providerType == AIProviderType.managedDeepSeek)
            const Text(
              'No setup needed — this uses the app\'s built-in DeepSeek '
              'assistant, with a limited number of free uses per day.',
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildApiKeyOnlyForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('API key'),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKeyController,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'API key'),
          onSubmitted: (value) {
            widget.controller.updateChatGptKey(value.isEmpty ? null : value);
          },
        ),
      ],
    );
  }

  Widget _buildCustomProviderForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Endpoint URL'),
        const SizedBox(height: 8),
        TextField(
          controller: _baseUrlController,
          decoration:
              const InputDecoration(hintText: 'e.g. https://api.deepseek.com'),
          onSubmitted: (_) => _saveCustomProvider(),
        ),
        const SizedBox(height: 16),
        const Text('API key'),
        const SizedBox(height: 8),
        TextField(
          controller: _customApiKeyController,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'API key'),
          onSubmitted: (_) => _saveCustomProvider(),
        ),
        const SizedBox(height: 16),
        const Text('Model'),
        const SizedBox(height: 8),
        TextField(
          controller: _modelController,
          decoration: const InputDecoration(hintText: 'e.g. deepseek-chat'),
          onSubmitted: (_) => _saveCustomProvider(),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _saveCustomProvider,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveCustomProvider() {
    widget.controller.updateCustomProviderConfig(
      baseUrl: _baseUrlController.text.isEmpty ? null : _baseUrlController.text,
      apiKey: _customApiKeyController.text.isEmpty
          ? null
          : _customApiKeyController.text,
      model: _modelController.text.isEmpty ? null : _modelController.text,
    );
  }

  String _labelFor(AIProviderType type) {
    switch (type) {
      case AIProviderType.gemini:
        return 'Gemini';
      case AIProviderType.chatgpt:
        return 'ChatGPT';
      case AIProviderType.customOpenAI:
        return 'Custom OpenAI-compatible provider (e.g. DeepSeek, local model)';
      case AIProviderType.managedDeepSeek:
        return 'Built-in DeepSeek assistant';
    }
  }
}
