/// Tarkistaa, että koodi on kelvollinen ISBN-13 (978/979-alku + tarkistenumero).
bool isValidIsbn13(String code) {
  if (!RegExp(r'^97[89]\d{10}$').hasMatch(code)) return false;
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(code[i]) * (i.isEven ? 1 : 3);
  }
  return (10 - sum % 10) % 10 == int.parse(code[12]);
}

/// Muuntaa 978-alkuisen ISBN-13:n ISBN-10:ksi. Palauttaa null, jos muunto ei onnistu
/// (esim. 979-alkuisilla ei ole ISBN-10-vastinetta).
String? isbn13To10(String isbn13) {
  if (!RegExp(r'^978\d{10}$').hasMatch(isbn13)) return null;
  final body = isbn13.substring(3, 12);
  var sum = 0;
  for (var i = 0; i < 9; i++) {
    sum += int.parse(body[i]) * (10 - i);
  }
  final check = (11 - sum % 11) % 11;
  return '$body${check == 10 ? 'X' : check}';
}
