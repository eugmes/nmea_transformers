import 'dart:convert';

import 'package:nmea_transformers/nmea_transformers.dart';
import 'package:test/test.dart';

void main() {
  group('nmea_transformer', () {
    // Known good messages
    const GPAAMMessage = '\$GPAAM,A,A,0.10,N,WPTNME*32';
    const AIVDMMessage = '!AIVDM,1,1,,A,14eG;o@034o8sd<L9i:a;WF>062D,0*7D';

    // Decoded good messages.
    final GPAAMDecoding = NmeaMessage(
        header: '\$GPAAM', fields: ['A', 'A', '0.10', 'N', 'WPTNME']);
    final AIVDMDecoding = NmeaMessage(
        header: '!AIVDM',
        fields: ['1', '1', '', 'A', '14eG;o@034o8sd<L9i:a;WF>062D', '0']);

    test('single GPAAM message', () {
      final stream = Stream.fromIterable([GPAAMMessage])
          .transform(ascii.encoder)
          .transform(NmeaTransformer());

      final expectedResult = [equals(GPAAMDecoding), emitsDone];

      expect(stream, emitsInOrder(expectedResult));
    });

    test('single AIVDM message', () {
      final stream = Stream.fromIterable([AIVDMMessage])
          .transform(ascii.encoder)
          .transform(NmeaTransformer());

      final expectedResult = [equals(AIVDMDecoding), emitsDone];

      expect(stream, emitsInOrder(expectedResult));
    });

    test('two messages in one chunk', () {
      final stream =
          Stream.fromIterable([GPAAMMessage + '\r\n' + AIVDMMessage + '\r\n'])
              .transform(ascii.encoder)
              .transform(NmeaTransformer());

      final expectedResult = [
        equals(GPAAMDecoding),
        equals(AIVDMDecoding),
        emitsDone
      ];

      expect(stream, emitsInOrder(expectedResult));
    });

    test('two messages in separate chunks', () {
      final stream =
          Stream.fromIterable([GPAAMMessage + '\r\n', AIVDMMessage + '\r\n'])
              .transform(ascii.encoder)
              .transform(NmeaTransformer());

      final expectedResult = [
        equals(GPAAMDecoding),
        equals(AIVDMDecoding),
        emitsDone
      ];

      expect(stream, emitsInOrder(expectedResult));
    });

    test('message split into two chunks', () {
      final stream = Stream.fromIterable(['\$GPAAM,A,A,', '0.10,N,WPTNME*32'])
          .transform(ascii.encoder)
          .transform(NmeaTransformer());

      final expectedResult = [equals(GPAAMDecoding), emitsDone];

      expect(stream, emitsInOrder(expectedResult));
    });

    test('invalid checksum', () {
      final stream = Stream.fromIterable(['\$GPAAM,A,A,', '0.10,N,WPTNME*42'])
          .transform(ascii.encoder)
          .transform(NmeaTransformer());

      final expectedResult = [emitsDone];

      expect(stream, emitsInOrder(expectedResult));
    });

    test('skips incomplete messages', () {
      final stream = Stream.fromIterable(
              ['!XXX', GPAAMMessage, '\$ZZZ,A', AIVDMMessage, '!XXX,'])
          .transform(ascii.encoder)
          .transform(NmeaTransformer());

      final expectedResult = [GPAAMDecoding, AIVDMDecoding, emitsDone];

      expect(stream, emitsInOrder(expectedResult));
    });

    test('long messages are skipped', () {
      final stream =
      Stream.fromIterable([GPAAMMessage + '\r\n', AIVDMMessage + '\r\n'])
          .transform(ascii.encoder)
          .transform(NmeaTransformer(maxLength: 24));

      final expectedResult = [
        equals(GPAAMDecoding),
        emitsDone
      ];

      expect(stream, emitsInOrder(expectedResult));
    });

    test('lowercase checksum', () {
      final stream = Stream.fromIterable(['!AIVDM,1,1,,A,14eG;o@034o8sd<L9i:a;WF>062D,0*7d'])
          .transform(ascii.encoder)
          .transform(NmeaTransformer());

      final expectedResult = [equals(AIVDMDecoding), emitsDone];

      expect(stream, emitsInOrder(expectedResult));
    });
  });
}
