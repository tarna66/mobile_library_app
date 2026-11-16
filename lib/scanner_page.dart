import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'book_page.dart';
import 'book_service.dart';
import 'isbn.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _controller = MobileScannerController(
    formats: [BarcodeFormat.ean13], // ISBN-13 on EAN-13-viivakoodi
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _service = BookService();

  bool _busy = false; // estää useamman haun samaan aikaan

  // Viivakoodinlukijan (näppäimistönä toimivan) syötteen puskuri
  final _buffer = StringBuffer();
  DateTime? _lastKeyTime;
  static const _maxKeyGap = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _controller.dispose();
    super.dispose();
  }

  /// Käsittelee fyysisen viivakoodinlukijan syötteen.
  /// Lukija (HID-tila) kirjoittaa numerot kuin näppäimistö, yleensä Enter perään.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!mounted || _busy) return false;
    // Ohitetaan, jos päällä on dialogi tai toinen sivu (esim. käsin syöttö)
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;

    // Jos edellisestä merkistä on kauan, aloitetaan puskuri alusta
    final now = DateTime.now();
    if (_lastKeyTime != null && now.difference(_lastKeyTime!) > _maxKeyGap) {
      _buffer.clear();
    }
    _lastKeyTime = now;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final code = _buffer.toString();
      _buffer.clear();
      if (isValidIsbn13(code)) {
        _lookup(code);
        return true;
      }
      return false;
    }

    final ch = event.character;
    if (ch != null && RegExp(r'^\d$').hasMatch(ch)) {
      _buffer.write(ch);
      // Osa lukijoista ei lähetä Enteriä, joten haetaan heti 13 numeron jälkeen
      if (_buffer.length == 13) {
        final code = _buffer.toString();
        _buffer.clear();
        if (isValidIsbn13(code)) {
          _lookup(code);
          return true;
        }
      }
    }
    return false;
  }

  /// Kameran tunnistama viivakoodi
  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || !isValidIsbn13(code)) return; // ei ISBN, ohitetaan
    _lookup(code);
  }

  /// Käsin syötetty ISBN
  Future<void> _enterManually() async {
    final textController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Syötä ISBN'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 13,
          decoration: const InputDecoration(hintText: '9789510000000'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Peruuta'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text),
            child: const Text('Hae'),
          ),
        ],
      ),
    );
    textController.dispose();

    if (code == null || code.isEmpty || !mounted) return;
    final cleaned = code.replaceAll(RegExp(r'[\s-]'), '');
    if (!isValidIsbn13(cleaned)) {
      _showMessage('Virheellinen ISBN-13: $cleaned');
      return;
    }
    _lookup(cleaned);
  }

  /// Hakee kirjan ja näyttää tuloksen (yhteinen kaikille syöttötavoille)
  Future<void> _lookup(String isbn) async {
    if (_busy) return;

    setState(() => _busy = true);
    await _controller.stop();

    try {
      final book = await _service.findByIsbn(isbn);
      if (!mounted) return;

      if (book == null) {
        _showMessage('Kirjaa ei löytynyt ISBN-koodilla $isbn');
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BookPage(book: book)),
        );
      }
    } catch (e) {
      if (mounted) _showMessage('Virhe haussa: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _controller.start(); // jatketaan skannausta
      }
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skannaa kirjan ISBN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            onPressed: _enterManually,
            tooltip: 'Syötä ISBN käsin',
          ),
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Taskulamppu',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Tähtäinkehys
          Center(
            child: Container(
              width: 280,
              height: 140,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_busy) const Center(child: CircularProgressIndicator()),
          const Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Text(
              'Osoita kameralla viivakoodia tai käytä viivakoodinlukijaa',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                shadows: [Shadow(blurRadius: 4)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
