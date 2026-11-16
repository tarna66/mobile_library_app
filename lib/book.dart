class Book {
  final String isbn;
  final String title;
  final List<String> authors;
  final String? coverUrl;
  final String? publisher;
  final String? publishDate;
  final int? pages;

  const Book({
    required this.isbn,
    required this.title,
    required this.authors,
    this.coverUrl,
    this.publisher,
    this.publishDate,
    this.pages,
  });
}
