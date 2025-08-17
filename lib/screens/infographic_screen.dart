import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart' as mobile_webview;
import 'package:webview_windows/webview_windows.dart' as windows_webview;
import 'package:file_saver/file_saver.dart';

class InfographicScreen extends StatefulWidget {
  final String infographicHtml;
  final String studentName;

  const InfographicScreen({
    Key? key,
    required this.infographicHtml,
    required this.studentName,
  }) : super(key: key);

  @override
  State<InfographicScreen> createState() => _InfographicScreenState();
}

class _InfographicScreenState extends State<InfographicScreen> {
  windows_webview.WebviewController? _windowsController;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _windowsController = windows_webview.WebviewController();
      _initWindowsWebView();
    }
  }

  Future<void> _initWindowsWebView() async {
    await _windowsController?.initialize();
    await _windowsController?.loadStringContent(widget.infographicHtml);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _windowsController?.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _saveInfographic() async {
    try {
      final bytes = utf8.encode(widget.infographicHtml);
      await FileSaver.instance.saveFile(
        name: 'Infographic-${widget.studentName}-${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
        bytes: bytes,
        fileExtension: 'html',
        mimeType: MimeType.custom,
        customMimeType: 'text/html',
      );
      _showSnackBar('Infographic saved to Downloads!');
    } catch (e) {
      _showSnackBar('Error saving infographic: $e', isError: true);
    }
  }

  Future<void> _shareInfographic() async {
    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/Infographic-${widget.studentName}.html';
      final file = File(path);
      await file.writeAsString(widget.infographicHtml);
      await Share.shareXFiles([XFile(path)],
          text: 'Infographic for ${widget.studentName}');
    } catch (e) {
      _showSnackBar('Error sharing infographic: $e', isError: true);
    }
  }

  Widget _buildWebView() {
    if (Platform.isWindows) {
      return _windowsController != null && _windowsController!.value.isInitialized
          ? windows_webview.Webview(_windowsController!)
          : const Center(child: CircularProgressIndicator());
    } else {
      final mobileController = mobile_webview.WebViewController()
        ..setJavaScriptMode(mobile_webview.JavaScriptMode.unrestricted)
        ..loadHtmlString(widget.infographicHtml);
      return mobile_webview.WebViewWidget(controller: mobileController);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Infographic for ${widget.studentName}'),
        // --- MODIFIED: Actions moved to a PopupMenuButton for a cleaner UI ---
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'share') {
                _shareInfographic();
              } else if (value == 'save') {
                _saveInfographic();
              }
            },
            icon: const Icon(Icons.more_vert),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'share',
                child: ListTile(leading: Icon(Icons.share_outlined), title: Text('Share Infographic')),
              ),
              const PopupMenuItem<String>(
                value: 'save',
                child: ListTile(leading: Icon(Icons.save_alt_outlined), title: Text('Save to Device')),
              ),
            ],
          ),
        ],
      ),
      body: _buildWebView(),
    );
  }
}
