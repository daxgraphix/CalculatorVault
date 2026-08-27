import 'dart:math' as math;

enum TokenType { number, plus, minus, multiply, divide, lparen, rparen, percent, eof }

class Token {
  final TokenType type;
  final String text;
  Token(this.type, this.text);
}

class CalculatorException implements Exception {
  final String message;
  CalculatorException(this.message);
  @override
  String toString() => message;
}

/// Tokenizes a calculator expression string into a token stream.
class Tokenizer {
  final String source;
  int _pos = 0;
  Tokenizer(this.source);

  List<Token> tokenize() {
    final tokens = <Token>[];
    while (_pos < source.length) {
      final c = source[_pos];
      if (c == ' ') {
        _pos++;
        continue;
      }
      if (RegExp(r'[0-9.]').hasMatch(c)) {
        final start = _pos;
        while (_pos < source.length && RegExp(r'[0-9.]').hasMatch(source[_pos])) {
          _pos++;
        }
        tokens.add(Token(TokenType.number, source.substring(start, _pos)));
        continue;
      }
      switch (c) {
        case '+':
          tokens.add(Token(TokenType.plus, c));
          break;
        case '-':
        case '−':
          tokens.add(Token(TokenType.minus, '-'));
          break;
        case '*':
        case '×':
          tokens.add(Token(TokenType.multiply, '*'));
          break;
        case '/':
        case '÷':
          tokens.add(Token(TokenType.divide, '/'));
          break;
        case '(':
          tokens.add(Token(TokenType.lparen, c));
          break;
        case ')':
          tokens.add(Token(TokenType.rparen, c));
          break;
        case '%':
          tokens.add(Token(TokenType.percent, c));
          break;
        default:
          throw CalculatorException('Unexpected character: $c');
      }
      _pos++;
    }
    tokens.add(Token(TokenType.eof, ''));
    return tokens;
  }
}

/// Recursive-descent parser + evaluator implementing standard precedence:
/// parentheses > unary minus > percent (postfix) > * / > + -
class ExpressionEvaluator {
  late List<Token> _tokens;
  int _pos = 0;

  double evaluate(String expression) {
    if (expression.trim().isEmpty) return 0;
    _tokens = Tokenizer(expression).tokenize();
    _pos = 0;
    final result = _parseAddSub();
    _expect(TokenType.eof);
    return result;
  }

  Token get _current => _tokens[_pos];

  Token _advance() => _tokens[_pos++];

  void _expect(TokenType type) {
    if (_current.type != type) {
      throw CalculatorException('Unexpected token: ${_current.text}');
    }
  }

  double _parseAddSub() {
    double left = _parseMulDiv();
    while (_current.type == TokenType.plus || _current.type == TokenType.minus) {
      final op = _advance();
      final right = _parseMulDiv();
      left = op.type == TokenType.plus ? left + right : left - right;
    }
    return left;
  }

  double _parseMulDiv() {
    double left = _parsePercent();
    while (_current.type == TokenType.multiply || _current.type == TokenType.divide) {
      final op = _advance();
      final right = _parsePercent();
      if (op.type == TokenType.divide) {
        if (right == 0) throw CalculatorException('Cannot divide by zero');
        left = left / right;
      } else {
        left = left * right;
      }
    }
    return left;
  }

  double _parsePercent() {
    double value = _parseUnary();
    while (_current.type == TokenType.percent) {
      _advance();
      value = value / 100;
    }
    return value;
  }

  double _parseUnary() {
    if (_current.type == TokenType.minus) {
      _advance();
      return -_parseUnary();
    }
    if (_current.type == TokenType.plus) {
      _advance();
      return _parseUnary();
    }
    return _parseAtom();
  }

  double _parseAtom() {
    if (_current.type == TokenType.number) {
      final tok = _advance();
      return double.parse(tok.text);
    }
    if (_current.type == TokenType.lparen) {
      _advance();
      final value = _parseAddSub();
      _expect(TokenType.rparen);
      _advance();
      return value;
    }
    throw CalculatorException('Unexpected token: ${_current.text}');
  }
}

/// Optional scientific functions, applied to a numeric operand before it
/// enters the expression (e.g. tapping "sin" wraps the current display value).
class ScientificFunctions {
  static double apply(String fn, double x, {bool degrees = true}) {
    final radians = degrees ? x * math.pi / 180 : x;
    switch (fn) {
      case 'sin':
        return math.sin(radians);
      case 'cos':
        return math.cos(radians);
      case 'tan':
        return math.tan(radians);
      case 'asin':
        return degrees ? math.asin(x) * 180 / math.pi : math.asin(x);
      case 'acos':
        return degrees ? math.acos(x) * 180 / math.pi : math.acos(x);
      case 'atan':
        return degrees ? math.atan(x) * 180 / math.pi : math.atan(x);
      case 'log':
        return math.log(x) / math.ln10;
      case 'ln':
        return math.log(x);
      case 'sqrt':
        return math.sqrt(x);
      case 'sqr':
        return x * x;
      case 'inv':
        return 1 / x;
      default:
        throw CalculatorException('Unknown function: $fn');
    }
  }
}
