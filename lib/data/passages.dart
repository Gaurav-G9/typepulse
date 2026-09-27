class Passage {
  final String id;
  final String title;
  final String language;
  final String category;
  final String text;

  const Passage({
    required this.id,
    required this.title,
    required this.language,
    required this.category,
    required this.text,
  });
}

class Passages {
  static const List<Passage> all = [
    Passage(
      id: 'en_civic',
      title: 'Civic Duty',
      language: 'en',
      category: 'Editorial',
      text:
          'A healthy republic depends on citizens who read carefully, vote independently, and hold public institutions to account. Speed without accuracy is noise. Practice until every keystroke is deliberate, then let rhythm follow.',
    ),
    Passage(
      id: 'en_office',
      title: 'Office Memo',
      language: 'en',
      category: 'Official',
      text:
          'All candidates must report fifteen minutes before the skill test. Mobile phones are not permitted inside the hall. The passage will be displayed on screen. Backspace is allowed. Results are computed from net speed and prescribed error rules.',
    ),
    Passage(
      id: 'en_climate',
      title: 'Climate Note',
      language: 'en',
      category: 'General',
      text:
          'Monsoon patterns have grown less predictable over the last two decades. Farmers adapt by mixing short-duration crops with traditional staples. Policy must follow evidence, not slogans, if rural incomes are to remain stable.',
    ),
    Passage(
      id: 'en_rail',
      title: 'Railway Notice',
      language: 'en',
      category: 'Exam style',
      text:
          'Passengers are requested to occupy reserved berths only after verifying the chart. Unreserved coaches must not be overcrowded. Any complaint regarding cleanliness should be recorded through the official helpline without delay.',
    ),
    Passage(
      id: 'hi_niti',
      title: 'Nagarik Niti',
      language: 'hi',
      category: 'Editorial',
      text:
          'Sushasan tabhi sambhav hai jab nagarik jagruk hon. Gati ke sath shuddhata bhi avashyak hai.',
    ),
    Passage(
      id: 'hi_karyalay',
      title: 'Karyalay Aadesh',
      language: 'hi',
      category: 'Official',
      text:
          'Sabhi abhyarthi kaushal pariksha se pandrah minute purva upasthit hon. Pariksha kaksh mein mobile varjit hai.',
    ),
  ];

  static List<Passage> byLang(String lang) =>
      all.where((p) => p.language == lang).toList();
}
