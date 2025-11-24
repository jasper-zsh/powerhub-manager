import 'state_context.dart';

/// Parses and evaluates boolean expressions such as
/// `(SW1.ON AND NOT SW2.OFF) OR SW3.ON`.
class SwitchHubConditionEvaluator {
  SwitchHubConditionEvaluator(this.context);

  final SwitchHubStateContext context;

  bool evaluate(String expression) {
    if (expression.trim().isEmpty) {
      return true;
    }
    final tokens = _Tokenizer(expression).tokenize();
    final parser = _Parser(tokens, context);
    return parser.parse();
  }
}

enum _TokenType { identifier, and, or, not, lParen, rParen, eof }

class _Token {
  _Token(this.type, this.lexeme);
  final _TokenType type;
  final String lexeme;
}

class _Tokenizer {
  _Tokenizer(this.source);

  final String source;
  int _index = 0;

  List<_Token> tokenize() {
    final tokens = <_Token>[];
    while (!_isAtEnd) {
      final char = source[_index];
      if (_isWhitespace(char)) {
        _index++;
        continue;
      }
      if (char == '(') {
        tokens.add(_Token(_TokenType.lParen, char));
        _index++;
        continue;
      }
      if (char == ')') {
        tokens.add(_Token(_TokenType.rParen, char));
        _index++;
        continue;
      }
      if (_isIdentifierChar(char)) {
        tokens.add(_consumeIdentifier());
        continue;
      }
      // Unsupported character, skip but surface via lexeme so that upstream can
      // report which token caused trouble.
      tokens.add(_Token(_TokenType.identifier, char));
      _index++;
    }
    tokens.add(_Token(_TokenType.eof, ''));
    return tokens;
  }

  bool get _isAtEnd => _index >= source.length;

  bool _isWhitespace(String char) => char.trim().isEmpty;

  bool _isIdentifierChar(String char) {
    final code = char.codeUnitAt(0);
    final isAlpha = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
    final isDigit = code >= 48 && code <= 57;
    return isAlpha || isDigit || char == '_' || char == '.' || char == '-';
  }

  _Token _consumeIdentifier() {
    final start = _index;
    while (!_isAtEnd && _isIdentifierChar(source[_index])) {
      _index++;
    }
    final lexeme = source.substring(start, _index);
    final keyword = lexeme.toUpperCase();
    switch (keyword) {
      case 'AND':
        return _Token(_TokenType.and, lexeme);
      case 'OR':
        return _Token(_TokenType.or, lexeme);
      case 'NOT':
        return _Token(_TokenType.not, lexeme);
      default:
        return _Token(_TokenType.identifier, lexeme);
    }
  }
}

class _Parser {
  _Parser(this.tokens, this.context);

  final List<_Token> tokens;
  final SwitchHubStateContext context;
  int _current = 0;

  bool parse() => _parseOr();

  bool _parseOr() {
    var value = _parseAnd();
    while (_match(_TokenType.or)) {
      value = value || _parseAnd();
    }
    return value;
  }

  bool _parseAnd() {
    var value = _parseUnary();
    while (_match(_TokenType.and)) {
      value = value && _parseUnary();
    }
    return value;
  }

  bool _parseUnary() {
    if (_match(_TokenType.not)) {
      return !_parseUnary();
    }
    return _parsePrimary();
  }

  bool _parsePrimary() {
    if (_match(_TokenType.lParen)) {
      final value = _parseOr();
      _consume(_TokenType.rParen);
      return value;
    }

    final token = _consume(_TokenType.identifier);
    if (token.lexeme.isEmpty) {
      return false;
    }
    return context.matchesIdentifier(token.lexeme);
  }

  bool _match(_TokenType type) {
    if (_check(type)) {
      _advance();
      return true;
    }
    return false;
  }

  _Token _consume(_TokenType type) {
    if (_check(type)) {
      return _advance();
    }
    return _Token(_TokenType.identifier, '');
  }

  bool _check(_TokenType type) {
    if (_isAtEnd) {
      return false;
    }
    return tokens[_current].type == type;
  }

  _Token _advance() {
    if (!_isAtEnd) {
      _current++;
    }
    return tokens[_current - 1];
  }

  bool get _isAtEnd => tokens[_current].type == _TokenType.eof;
}
