import 'package:flutter/material.dart';
import 'book.dart';

class BookPage extends StatelessWidget {
  final Book book;
  const BookPage({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kirjan tiedot')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (book.coverUrl != null)
            Center(
              child: Image.network(
                book.coverUrl!,
                height: 240,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.menu_book, size: 120),
              ),
            )
          else
            const Icon(Icons.menu_book, size: 120),
          const SizedBox(height: 16),
          Text(book.title, style: textTheme.headlineSmall),
          if (book.authors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(book.authors.join(', '), style: textTheme.titleMedium),
          ],
          const SizedBox(height: 16),
          _row('ISBN', book.isbn),
          if (book.publisher != null) _row('Kustantaja', book.publisher!),
          if (book.publishDate != null) _row('Julkaistu', book.publishDate!),
          if (book.pages != null) _row('Sivuja', '${book.pages}'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
