import 'dart:convert';

import 'package:nmea_transformers/nmea_transformers.dart';

void main() {
  var messages = [
    '\$GPAAM,A,A,0.10,N,WPTNME*32\r\n',
    '!AIVDM,1,1,,A,14eG;o@034o8sd<L9i:a;WF>062D,0*7D\r\n'
  ];

  Stream.fromIterable(messages)
      .transform(ascii.encoder)
      .transform(NmeaTransformer())
      .listen((msg) {
    print('Parsed message: $msg');
    print('   header: ${msg.header}');
    print('   fields: ${msg.fields}');
  });
}
