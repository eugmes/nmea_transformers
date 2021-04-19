import 'dart:async';

import 'package:charcode/ascii.dart';
import 'package:collection/collection.dart';

/// Separated NMEA message.
class NmeaMessage {
  final String header;
  final List<String> fields;

  NmeaMessage({required this.header, required this.fields});

  @override
  String toString() {
    return header + ',' + fields.join(',');
  }

  @override
  bool operator ==(Object other) {
    const eq = ListEquality<String>();

    return other is NmeaMessage &&
        header == other.header &&
        eq.equals(fields, other.fields);
  }
}

enum _ParseState {
  INITIAL,
  DATA,
  CHECKSUM1,
  CHECKSUM2,
}

int? _hex(int c) {
  if (c >= $0 && c <= $9) {
    return c - $0;
  } else if (c >= $A && c <= $F) {
    return c - $A + 10;
  } else if (c >= $a && c <= $f) {
    return c - $a + 10;
  }
  return null;
}

class _NmeaSink implements EventSink<List<int>> {
  final EventSink<NmeaMessage> _outputSink;

  final int? maxLength;
  _ParseState _state = _ParseState.INITIAL;
  final StringBuffer _buf = StringBuffer();

  /// Checksum at the end of the message.
  int _checksumVal = 0;

  _NmeaSink(this.maxLength, this._outputSink);

  void _resetState({_ParseState newState = _ParseState.INITIAL}) {
    _buf.clear();
    _checksumVal = 0;
    _state = newState;
  }

  void _resetToHeader(int c) {
    _resetState(newState: _ParseState.DATA);
    _buf.writeCharCode(c);
  }

  void _handleSymbol(int c) {
    if (c == $exclamation || c == $$) {
      _resetToHeader(c);
      return;
    }

    switch (_state) {
      case _ParseState.INITIAL:
        break;
      case _ParseState.DATA:
        if (c == $asterisk) {
          _state = _ParseState.CHECKSUM1;
        } else if (c >= 0x20 && c <= 0xFF) {
          _buf.writeCharCode(c);
          var maxChars = maxLength;
          if (maxChars != null && _buf.length > maxChars) {
            _resetState();
          }
        } else {
          _resetState();
        }
        break;
      case _ParseState.CHECKSUM1:
        var digit = _hex(c);
        if (digit != null) {
          _checksumVal = digit;
          _state = _ParseState.CHECKSUM2;
        } else {
          _resetState();
        }
        break;
      case _ParseState.CHECKSUM2:
        var digit = _hex(c);
        if (digit != null) {
          _checksumVal = _checksumVal * 16 + digit;
          var data = _buf.toString();
          var sum = 0;
          for (var i = 1; i < data.length; i++) {
            sum = sum ^ data.codeUnitAt(i);
          }

          if (sum == _checksumVal) {
            var parts = data.split(',');
            var message =
                NmeaMessage(header: parts.first, fields: parts.sublist(1));
            _outputSink.add(message);
          }
          _resetState();
        }
        break;
    }
  }

  @override
  void add(List<int> data) {
    for (var c in data) {
      _handleSymbol(c);
    }
  }

  @override
  void addError(e, [st]) => _outputSink.addError(e, st);

  @override
  void close() => _outputSink.close();
}

class NmeaTransformer extends StreamTransformerBase<List<int>, NmeaMessage> {
  final int? maxLength;

  NmeaTransformer({this.maxLength});

  @override
  Stream<NmeaMessage> bind(Stream<List<int>> stream) =>
      Stream.eventTransformed(stream, (sink) => _NmeaSink(maxLength, sink));
}
