import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/services/map_link.dart';

void main() {
  group('isGoogleMapsLink', () {
    test('accepts the links Google Maps gives out', () {
      for (final ok in [
        'https://maps.app.goo.gl/AbCdEf123',
        'https://goo.gl/maps/AbCdEf',
        'https://www.google.com/maps/place/Lal+Chowk/@34.07,74.80,17z',
        'https://google.com/maps?q=34.07,74.80',
        'https://www.google.co.in/maps/search/?api=1&query=34.07,74.80',
        'https://maps.google.com/?q=Lal+Chowk',
        'http://maps.app.goo.gl/AbCdEf',
      ]) {
        expect(MapLink.isGoogleMapsLink(ok), isTrue, reason: ok);
      }
    });

    test('rejects everything else', () {
      for (final bad in [
        '',
        'Lal Chowk',
        'maps.app.goo.gl/AbCdEf', // no scheme
        'https://maps.app.goo.gl/', // no link id
        'https://www.google.com/search?q=maps', // not Maps
        'https://google.com.evil.com/maps/x', // look-alike host
        'https://evil.com/maps.google.com',
        'https://goo.gl/other',
        'javascript:alert(1)',
        'ftp://maps.google.com/x',
      ]) {
        expect(MapLink.isGoogleMapsLink(bad), isFalse, reason: bad);
      }
    });
  });

  group('extract / split / join', () {
    const link = 'https://maps.app.goo.gl/AbCdEf';

    test('finds the link inside other text', () {
      expect(MapLink.extractLink('Check this place $link thanks'), link);
      expect(MapLink.extractLink('($link).'), link);
      expect(MapLink.extractLink('see https://evil.com/x'), isNull);
    });

    test('splits an address from its link', () {
      expect(MapLink.split('Lal Chowk, Srinagar $link'),
          (text: 'Lal Chowk, Srinagar', link: link));
      expect(MapLink.split('Lal Chowk | $link'),
          (text: 'Lal Chowk', link: link));
      expect(MapLink.split(link), (text: '', link: link));
    });

    test('an old address with no link stays as it is', () {
      expect(MapLink.split('  Rajbagh '), (text: 'Rajbagh', link: null));
      expect(MapLink.split(''), (text: '', link: null));
    });

    test('join puts the link after the text, and round-trips', () {
      final stored = MapLink.join('Lal Chowk, Srinagar', link);
      expect(stored, 'Lal Chowk, Srinagar $link');
      expect(MapLink.split(stored), (text: 'Lal Chowk, Srinagar', link: link));
    });

    test('a new link replaces the old one; an empty box removes it', () {
      const other = 'https://goo.gl/maps/Zz9';
      expect(MapLink.join('Lal Chowk $link', other), 'Lal Chowk $other');
      expect(MapLink.join('Lal Chowk', ''), 'Lal Chowk');
      expect(MapLink.join('Lal Chowk', null), 'Lal Chowk');
    });

    test('a link typed inside the address box is kept', () {
      expect(MapLink.join('Lal Chowk $link'), 'Lal Chowk $link');
      expect(MapLink.join('Lal Chowk $link', ''), 'Lal Chowk $link');
    });

    test('a link with nothing valid in it is dropped', () {
      expect(MapLink.join('Lal Chowk', 'https://evil.com'), 'Lal Chowk');
    });
  });

  group('target', () {
    test('uses the pin when there is one', () {
      expect(
        MapLink.target(
            address: 'Lal Chowk https://maps.app.goo.gl/AbCdEf',
            locality: 'Srinagar'),
        Uri.parse('https://maps.app.goo.gl/AbCdEf'),
      );
    });

    test('searches the address with the locality and region', () {
      final u = MapLink.target(address: 'Rajbagh', locality: 'Soura')!;
      expect(u.host, 'www.google.com');
      expect(u.path, '/maps/search/');
      expect(u.queryParameters['api'], '1');
      expect(u.queryParameters['query'], 'Rajbagh, Soura, Jammu and Kashmir');
    });

    test('does not repeat what the address already says', () {
      final u = MapLink.target(
          address: 'Near Clock Tower, Soura, Kashmir', locality: 'Soura')!;
      expect(u.queryParameters['query'], 'Near Clock Tower, Soura, Kashmir');
    });

    test('with no address it searches the business name in its locality', () {
      final u = MapLink.target(
          address: '', locality: 'Bemina', businessName: 'FixIt Hub')!;
      expect(u.queryParameters['query'], 'FixIt Hub, Bemina, Jammu and Kashmir');
    });

    test('nothing to look for gives null', () {
      expect(MapLink.target(address: '', locality: '', businessName: 'X'), isNull);
      expect(MapLink.target(address: '  ', locality: 'Soura'), isNull);
    });
  });

  group('GPS and place lookup', () {
    test('a pin from coordinates is itself a valid Maps link', () {
      final pin = MapLink.pinFromCoordinates(34.0836, 74.7973);
      expect(pin,
          'https://www.google.com/maps/search/?api=1&query=34.083600,74.797300');
      expect(MapLink.isGoogleMapsLink(pin), isTrue);
    });

    test('composeAddress drops empties, repeats and Plus Codes', () {
      expect(
        MapLink.composeAddress([
          'WJ5P+XX',
          'Lal Chowk',
          null,
          '',
          'Srinagar',
          'srinagar',
          'Jammu & Kashmir',
          '190001',
        ]),
        'Lal Chowk, Srinagar, Jammu & Kashmir, 190001',
      );
      expect(MapLink.composeAddress([null, ' ']), '');
    });
  });
}
