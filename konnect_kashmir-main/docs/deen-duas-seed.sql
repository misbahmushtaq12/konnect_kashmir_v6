-- Konnect Kashmir: Deen duas (the same 12 duas the mobile app shows).
-- Generated from the app's source (lib/screens/deen/deen_data.dart, kDuas); nothing was retyped.
-- This table does NOT exist yet. Run in the Supabase SQL editor, then add the access policies (see below).

create table if not exists public.deen_duas (
  id          uuid primary key default gen_random_uuid(),
  sort_order  integer     not null default 0,
  arabic      text        not null,
  title_en    text        not null,
  title_hi    text        not null default '',
  title_ur    text        not null default '',
  meaning_en  text        not null,
  meaning_hi  text        not null default '',
  meaning_ur  text        not null default '',
  source      text        not null default '',
  is_active   boolean     not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.deen_duas enable row level security;

-- Everyone (the website and the app, signed in or not) may read active duas.
drop policy if exists "deen_duas public read" on public.deen_duas;
create policy "deen_duas public read" on public.deen_duas
  for select using (is_active);

-- Writing (insert / update / delete, and reading inactive rows) is for admins only:
-- copy the admin policies of public.audio_reciters (same admin check), do not invent a new one.

-- The 12 duas (safe to run twice: a dua whose Arabic text is already there is skipped).
insert into public.deen_duas
  (sort_order, arabic, title_en, title_hi, title_ur, meaning_en, meaning_hi, meaning_ur, source, is_active)
select v.* from (values
  (1, $q$بِسْمِ اللَّهِ$q$, $q$Before eating$q$, $q$खाने से पहले$q$, $q$کھانے سے پہلے$q$, $q$In the name of Allah.$q$, $q$अल्लाह के नाम से।$q$, $q$اللہ کے نام سے۔$q$, $q$Abu Dawud, Tirmidhi$q$, true),
  (2, $q$الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا وَجَعَلَنَا مُسْلِمِينَ$q$, $q$After eating$q$, $q$खाने के बाद$q$, $q$کھانے کے بعد$q$, $q$All praise is for Allah who fed us, gave us drink and made us Muslims.$q$, $q$सारी प्रशंसा अल्लाह के लिए है जिसने हमें खिलाया, पिलाया और मुसलमान बनाया।$q$, $q$تمام تعریفیں اللہ کے لیے ہیں جس نے ہمیں کھلایا، پلایا اور مسلمان بنایا۔$q$, $q$Abu Dawud, Tirmidhi$q$, true),
  (3, $q$الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ$q$, $q$On waking up$q$, $q$सुबह उठकर$q$, $q$صبح اٹھ کر$q$, $q$All praise is for Allah who gave us life after causing us to die, and to Him is the resurrection.$q$, $q$सारी प्रशंसा अल्लाह के लिए है जिसने हमें मौत के बाद ज़िंदगी दी, और उसी की ओर लौटना है।$q$, $q$تمام تعریفیں اللہ کے لیے ہیں جس نے ہمیں موت کے بعد زندگی دی، اور اسی کی طرف لوٹنا ہے۔$q$, $q$Sahih al-Bukhari$q$, true),
  (4, $q$بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا$q$, $q$Before sleeping$q$, $q$सोने से पहले$q$, $q$سونے سے پہلے$q$, $q$In Your name, O Allah, I die and I live.$q$, $q$ऐ अल्लाह! तेरे ही नाम से मैं मरता हूँ और जीता हूँ।$q$, $q$اے اللہ! تیرے ہی نام سے میں مرتا ہوں اور جیتا ہوں۔$q$, $q$Sahih al-Bukhari$q$, true),
  (5, $q$بِسْمِ اللَّهِ تَوَكَّلْتُ عَلَى اللَّهِ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ$q$, $q$Leaving home$q$, $q$घर से निकलते समय$q$, $q$گھر سے نکلتے وقت$q$, $q$In the name of Allah, I place my trust in Allah; there is no power and no strength except with Allah.$q$, $q$अल्लाह के नाम से, मैंने अल्लाह पर भरोसा किया; अल्लाह के बिना न कोई ताक़त है न कोई शक्ति।$q$, $q$اللہ کے نام سے، میں نے اللہ پر بھروسا کیا؛ اللہ کے بغیر نہ کوئی طاقت ہے نہ کوئی قوت۔$q$, $q$Abu Dawud, Tirmidhi$q$, true),
  (6, $q$اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ$q$, $q$Entering the mosque$q$, $q$मस्जिद में दाख़िल होते समय$q$, $q$مسجد میں داخل ہوتے وقت$q$, $q$O Allah, open for me the doors of Your mercy.$q$, $q$ऐ अल्लाह! मेरे लिए अपनी रहमत के दरवाज़े खोल दे।$q$, $q$اے اللہ! میرے لیے اپنی رحمت کے دروازے کھول دے۔$q$, $q$Sahih Muslim$q$, true),
  (7, $q$اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ$q$, $q$Leaving the mosque$q$, $q$मस्जिद से निकलते समय$q$, $q$مسجد سے نکلتے وقت$q$, $q$O Allah, I ask You for Your bounty.$q$, $q$ऐ अल्लाह! मैं तुझसे तेरे फ़ज़्ल का सवाल करता हूँ।$q$, $q$اے اللہ! میں تجھ سے تیرے فضل کا سوال کرتا ہوں۔$q$, $q$Sahih Muslim$q$, true),
  (8, $q$سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَى رَبِّنَا لَمُنقَلِبُونَ$q$, $q$Starting a journey$q$, $q$सफ़र शुरू करते समय$q$, $q$سفر شروع کرتے وقت$q$, $q$Glory to Him who has subjected this to us, and we could never have it by ourselves; and to our Lord we shall return.$q$, $q$पाक है वह जिसने इसे हमारे वश में कर दिया, वरना हम इसे वश में न कर सकते थे, और हम अपने रब की ओर लौटने वाले हैं।$q$, $q$پاک ہے وہ جس نے اسے ہمارے بس میں کر دیا، ورنہ ہم اسے بس میں نہ کر سکتے تھے، اور ہم اپنے رب کی طرف لوٹنے والے ہیں۔$q$, $q$Quran 43:13-14$q$, true),
  (9, $q$رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ$q$, $q$Good in this life and the next$q$, $q$दुनिया और आख़िरत की भलाई$q$, $q$دنیا اور آخرت کی بھلائی$q$, $q$Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.$q$, $q$ऐ हमारे रब! हमें दुनिया में भलाई दे और आख़िरत में भी भलाई दे, और हमें आग के अज़ाब से बचा।$q$, $q$اے ہمارے رب! ہمیں دنیا میں بھلائی دے اور آخرت میں بھی بھلائی دے، اور ہمیں آگ کے عذاب سے بچا۔$q$, $q$Quran 2:201$q$, true),
  (10, $q$رَبِّ زِدْنِي عِلْمًا$q$, $q$For more knowledge$q$, $q$इल्म में बढ़ोतरी के लिए$q$, $q$علم میں اضافے کے لیے$q$, $q$My Lord, increase me in knowledge.$q$, $q$ऐ मेरे रब! मेरे इल्म में इज़ाफ़ा फ़रमा।$q$, $q$اے میرے رب! میرے علم میں اضافہ فرما۔$q$, $q$Quran 20:114$q$, true),
  (11, $q$رَبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا$q$, $q$For parents$q$, $q$माता-पिता के लिए$q$, $q$والدین کے لیے$q$, $q$My Lord, have mercy on them as they brought me up when I was small.$q$, $q$ऐ मेरे रब! उन दोनों पर रहम फ़रमा जैसे उन्होंने बचपन में मुझे पाला।$q$, $q$اے میرے رب! ان دونوں پر رحم فرما جیسے انہوں نے بچپن میں مجھے پالا۔$q$, $q$Quran 17:24$q$, true),
  (12, $q$رَبَّنَا ظَلَمْنَا أَنفُسَنَا وَإِن لَّمْ تَغْفِرْ لَنَا وَتَرْحَمْنَا لَنَكُونَنَّ مِنَ الْخَاسِرِينَ$q$, $q$Seeking forgiveness$q$, $q$माफ़ी माँगना$q$, $q$مغفرت طلب کرنا$q$, $q$Our Lord, we have wronged ourselves; if You do not forgive us and have mercy on us, we will surely be among the losers.$q$, $q$ऐ हमारे रब! हमने अपने ऊपर ज़ुल्म किया; अगर तू हमें माफ़ न करे और हम पर रहम न करे तो हम घाटे में पड़ जाएँगे।$q$, $q$اے ہمارے رب! ہم نے اپنی جانوں پر ظلم کیا؛ اگر تو ہمیں معاف نہ کرے اور ہم پر رحم نہ کرے تو ہم نقصان اٹھانے والوں میں ہو جائیں گے۔$q$, $q$Quran 7:23$q$, true)
) as v(sort_order, arabic, title_en, title_hi, title_ur, meaning_en, meaning_hi, meaning_ur, source, is_active)
where not exists (select 1 from public.deen_duas x where x.arabic = v.arabic);
