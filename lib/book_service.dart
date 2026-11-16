import 'dart:convert';
import 'package:http/http.dart' as http;
import 'book.dart';
import 'isbn.dart';

/// Hakee kirjan tiedot ISBN-koodilla Finnasta (api.finna.fi).
///
/// Huomioita:
/// - Finna vaatii kuvaavan User-Agent-otsikon, muuten vastaus on 403.
///   Vaihda alla oleva yhteystieto omaksesi.
/// - Finnan rajapintaa saa käyttää noin yksi pyyntö sekunnissa.
class BookService {
  static const _userAgent = 'IsbnScannerApp/1.0 (oma.sahkoposti@example.com)';

  static const _fields = [
    'id',
    'title',
    'nonPresenterAuthors',
    'publishers',
    'year',
    'images',
    'physicalDescriptions',
    'formats',
  ];

  /// Palauttaa null, jos kirjaa ei löydy.
  /// Heittää poikkeuksen verkko- tai rajapintavirheen yhteydessä.
  Future<Book?> findByIsbn(String isbn) async {
    var book = await _search(isbn, isbn);

    // Vanhemmat kirjat on voitu luetteloida ISBN-10-koodilla
    if (book == null) {
      final isbn10 = isbn13To10(isbn);
      if (isbn10 != null) {
        await Future.delayed(const Duration(seconds: 1)); // 1 pyyntö/s
        book = await _search(isbn10, isbn);
      }
    }
    return book;
  }

  Future<Book?> _search(String query, String isbn) async {
    final uri = Uri.https('api.finna.fi', '/v1/search', {
      'lookfor': query,
      'type': 'ISN', // ISBN/ISSN-indeksi
      'field[]': _fields,
      'limit': '10',
    });

    final response = await http
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 429) {
      throw Exception('Finna rajoittaa hakuja, yritä hetken kuluttua uudelleen');
    }
    if (response.statusCode != 200) {
      throw Exception('Finna-haku epäonnistui (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final records = (json['records'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (records.isEmpty) return null;

    // Sama ISBN voi löytyä useana painoksena (kirja, e-kirja, äänikirja),
    // valitaan parhaiten pisteytetty, ensisijaisesti painettu kirja.
    records.sort((a, b) => _score(b).compareTo(_score(a)));
    return _toBook(records.first, isbn);
  }

  int _score(Map<String, dynamic> r) {
    var score = 0;
    final formats = (r['formats'] as List<dynamic>? ?? [])
        .map((f) => (f as Map<String, dynamic>)['value']?.toString() ?? '')
        .toList();

    if (formats.any((f) => f.contains('/Book/Book'))) score += 4;
    if (formats.any((f) => f.contains('eBook') || f.contains('AudioBook'))) {
      score -= 2;
    }
    if ((r['images'] as List<dynamic>?)?.isNotEmpty ?? false) score += 2;
    if ((r['nonPresenterAuthors'] as List<dynamic>?)?.isNotEmpty ?? false) {
      score += 1;
    }
    return score;
  }

  Book _toBook(Map<String, dynamic> r, String isbn) {
    // Tekijät: Finna antaa muodossa "Sukunimi, Etunimi" -> "Etunimi Sukunimi"
    final authors = <String>{
      for (final a in (r['nonPresenterAuthors'] as List<dynamic>? ?? []))
        if ((a as Map<String, dynamic>)['name'] != null)
          _naturalName(a['name'] as String),
    }.toList();

    final images = r['images'] as List<dynamic>?;
    String? cover;
    if (images != null && images.isNotEmpty) {
      final path = images.first as String;
      cover = path.startsWith('http') ? path : 'https://www.finna.fi$path';
    }

    final publishers = r['publishers'] as List<dynamic>?;

    return Book(
      isbn: isbn,
      title: _cleanTitle(r['title'] as String? ?? 'Tuntematon nimi'),
      authors: authors,
      coverUrl: cover,
      publisher: publishers != null && publishers.isNotEmpty
          ? _cleanTitle(publishers.first.toString())
          : null,
      publishDate: r['year']?.toString(),
      pages: _parsePages(r['physicalDescriptions'] as List<dynamic>?),
    );
  }

  String _naturalName(String name) {
    final parts = name.split(',');
    if (parts.length == 2) return '${parts[1].trim()} ${parts[0].trim()}';
    return name.trim();
  }

  /// Poistaa luettelointimerkit nimen lopusta, esim. "Tuntematon sotilas /"
  String _cleanTitle(String s) => s.replaceAll(RegExp(r'\s*[/:;,]\s*$'), '').trim();

  /// Poimii sivumäärän tekstistä, esim. "320 sivua : kuvitettu"
  int? _parsePages(List<dynamic>? descriptions) {
    if (descriptions == null) return null;
    for (final d in descriptions) {
      final m = RegExp(r'(\d+)\s*(?:sivua|s\.|p\.|pages)').firstMatch(d.toString());
      if (m != null) return int.parse(m.group(1)!);
    }
    return null;
  }
}
