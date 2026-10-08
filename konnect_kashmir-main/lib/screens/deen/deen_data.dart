import 'package:flutter/widgets.dart';

/// A reciter whose full-surah recordings are streamed from quranicaudio.com
/// (every entry below was checked to serve audio for every surah number).
class Reciter {
  final String name;
  final String slug;
  const Reciter(this.name, this.slug);

  /// The files are numbered with three digits: 001.mp3 ... 114.mp3.
  String surahUrl(int surah) =>
      'https://download.quranicaudio.com/quran/$slug/${surah.toString().padLeft(3, '0')}.mp3';
}

const List<Reciter> kReciters = [
  Reciter('Mishary Rashid Alafasy', 'mishaari_raashid_al_3afaasee'),
  Reciter('Abdurrahmaan As-Sudais', 'abdurrahmaan_as-sudays'),
  Reciter('Maher Al-Muaiqly', 'maher_almu3aiqly/year1440'),
  Reciter('Mahmoud Khalil Al-Husary', 'mahmood_khaleel_al-husaree'),
  Reciter('Muhammad Siddiq Al-Minshawi', 'muhammad_siddeeq_al-minshaawee'),
  Reciter('Abdullah Awad Al-Juhany', 'abdullaah_3awwaad_al-juhaynee'),
];

class Dua {
  final String arabic;

  /// {'en': ..., 'hi': ..., 'ur': ...}
  final Map<String, String> title;
  final Map<String, String> meaning;
  final String source;
  const Dua(this.arabic, this.title, this.meaning, this.source);

  String titleFor(Locale l) => title[l.languageCode] ?? title['en']!;
  String meaningFor(Locale l) => meaning[l.languageCode] ?? meaning['en']!;
}

const List<Dua> kDuas = [
  Dua(
    'بِسْمِ اللَّهِ',
    {'en': 'Before eating', 'hi': 'खाने से पहले', 'ur': 'کھانے سے پہلے'},
    {
      'en': 'In the name of Allah.',
      'hi': 'अल्लाह के नाम से।',
      'ur': 'اللہ کے نام سے۔',
    },
    'Abu Dawud, Tirmidhi',
  ),
  Dua(
    'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا وَجَعَلَنَا مُسْلِمِينَ',
    {'en': 'After eating', 'hi': 'खाने के बाद', 'ur': 'کھانے کے بعد'},
    {
      'en': 'All praise is for Allah who fed us, gave us drink and made us Muslims.',
      'hi': 'सारी प्रशंसा अल्लाह के लिए है जिसने हमें खिलाया, पिलाया और मुसलमान बनाया।',
      'ur': 'تمام تعریفیں اللہ کے لیے ہیں جس نے ہمیں کھلایا، پلایا اور مسلمان بنایا۔',
    },
    'Abu Dawud, Tirmidhi',
  ),
  Dua(
    'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
    {'en': 'On waking up', 'hi': 'सुबह उठकर', 'ur': 'صبح اٹھ کر'},
    {
      'en': 'All praise is for Allah who gave us life after causing us to die, and to Him is the resurrection.',
      'hi': 'सारी प्रशंसा अल्लाह के लिए है जिसने हमें मौत के बाद ज़िंदगी दी, और उसी की ओर लौटना है।',
      'ur': 'تمام تعریفیں اللہ کے لیے ہیں جس نے ہمیں موت کے بعد زندگی دی، اور اسی کی طرف لوٹنا ہے۔',
    },
    'Sahih al-Bukhari',
  ),
  Dua(
    'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
    {'en': 'Before sleeping', 'hi': 'सोने से पहले', 'ur': 'سونے سے پہلے'},
    {
      'en': 'In Your name, O Allah, I die and I live.',
      'hi': 'ऐ अल्लाह! तेरे ही नाम से मैं मरता हूँ और जीता हूँ।',
      'ur': 'اے اللہ! تیرے ہی نام سے میں مرتا ہوں اور جیتا ہوں۔',
    },
    'Sahih al-Bukhari',
  ),
  Dua(
    'بِسْمِ اللَّهِ تَوَكَّلْتُ عَلَى اللَّهِ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
    {'en': 'Leaving home', 'hi': 'घर से निकलते समय', 'ur': 'گھر سے نکلتے وقت'},
    {
      'en': 'In the name of Allah, I place my trust in Allah; there is no power and no strength except with Allah.',
      'hi': 'अल्लाह के नाम से, मैंने अल्लाह पर भरोसा किया; अल्लाह के बिना न कोई ताक़त है न कोई शक्ति।',
      'ur': 'اللہ کے نام سے، میں نے اللہ پر بھروسا کیا؛ اللہ کے بغیر نہ کوئی طاقت ہے نہ کوئی قوت۔',
    },
    'Abu Dawud, Tirmidhi',
  ),
  Dua(
    'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
    {'en': 'Entering the mosque', 'hi': 'मस्जिद में दाख़िल होते समय', 'ur': 'مسجد میں داخل ہوتے وقت'},
    {
      'en': 'O Allah, open for me the doors of Your mercy.',
      'hi': 'ऐ अल्लाह! मेरे लिए अपनी रहमत के दरवाज़े खोल दे।',
      'ur': 'اے اللہ! میرے لیے اپنی رحمت کے دروازے کھول دے۔',
    },
    'Sahih Muslim',
  ),
  Dua(
    'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ',
    {'en': 'Leaving the mosque', 'hi': 'मस्जिद से निकलते समय', 'ur': 'مسجد سے نکلتے وقت'},
    {
      'en': 'O Allah, I ask You for Your bounty.',
      'hi': 'ऐ अल्लाह! मैं तुझसे तेरे फ़ज़्ल का सवाल करता हूँ।',
      'ur': 'اے اللہ! میں تجھ سے تیرے فضل کا سوال کرتا ہوں۔',
    },
    'Sahih Muslim',
  ),
  Dua(
    'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَى رَبِّنَا لَمُنقَلِبُونَ',
    {'en': 'Starting a journey', 'hi': 'सफ़र शुरू करते समय', 'ur': 'سفر شروع کرتے وقت'},
    {
      'en': 'Glory to Him who has subjected this to us, and we could never have it by ourselves; and to our Lord we shall return.',
      'hi': 'पाक है वह जिसने इसे हमारे वश में कर दिया, वरना हम इसे वश में न कर सकते थे, और हम अपने रब की ओर लौटने वाले हैं।',
      'ur': 'پاک ہے وہ جس نے اسے ہمارے بس میں کر دیا، ورنہ ہم اسے بس میں نہ کر سکتے تھے، اور ہم اپنے رب کی طرف لوٹنے والے ہیں۔',
    },
    'Quran 43:13-14',
  ),
  Dua(
    'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
    {'en': 'Good in this life and the next', 'hi': 'दुनिया और आख़िरत की भलाई', 'ur': 'دنیا اور آخرت کی بھلائی'},
    {
      'en': 'Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.',
      'hi': 'ऐ हमारे रब! हमें दुनिया में भलाई दे और आख़िरत में भी भलाई दे, और हमें आग के अज़ाब से बचा।',
      'ur': 'اے ہمارے رب! ہمیں دنیا میں بھلائی دے اور آخرت میں بھی بھلائی دے، اور ہمیں آگ کے عذاب سے بچا۔',
    },
    'Quran 2:201',
  ),
  Dua(
    'رَبِّ زِدْنِي عِلْمًا',
    {'en': 'For more knowledge', 'hi': 'इल्म में बढ़ोतरी के लिए', 'ur': 'علم میں اضافے کے لیے'},
    {
      'en': 'My Lord, increase me in knowledge.',
      'hi': 'ऐ मेरे रब! मेरे इल्म में इज़ाफ़ा फ़रमा।',
      'ur': 'اے میرے رب! میرے علم میں اضافہ فرما۔',
    },
    'Quran 20:114',
  ),
  Dua(
    'رَبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا',
    {'en': 'For parents', 'hi': 'माता-पिता के लिए', 'ur': 'والدین کے لیے'},
    {
      'en': 'My Lord, have mercy on them as they brought me up when I was small.',
      'hi': 'ऐ मेरे रब! उन दोनों पर रहम फ़रमा जैसे उन्होंने बचपन में मुझे पाला।',
      'ur': 'اے میرے رب! ان دونوں پر رحم فرما جیسے انہوں نے بچپن میں مجھے پالا۔',
    },
    'Quran 17:24',
  ),
  Dua(
    'رَبَّنَا ظَلَمْنَا أَنفُسَنَا وَإِن لَّمْ تَغْفِرْ لَنَا وَتَرْحَمْنَا لَنَكُونَنَّ مِنَ الْخَاسِرِينَ',
    {'en': 'Seeking forgiveness', 'hi': 'माफ़ी माँगना', 'ur': 'مغفرت طلب کرنا'},
    {
      'en': 'Our Lord, we have wronged ourselves; if You do not forgive us and have mercy on us, we will surely be among the losers.',
      'hi': 'ऐ हमारे रब! हमने अपने ऊपर ज़ुल्म किया; अगर तू हमें माफ़ न करे और हम पर रहम न करे तो हम घाटे में पड़ जाएँगे।',
      'ur': 'اے ہمارے رب! ہم نے اپنی جانوں پر ظلم کیا؛ اگر تو ہمیں معاف نہ کرے اور ہم پر رحم نہ کرے تو ہم نقصان اٹھانے والوں میں ہو جائیں گے۔',
    },
    'Quran 7:23',
  ),
];
