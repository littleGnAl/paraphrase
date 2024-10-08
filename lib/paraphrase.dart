import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart'
    show AnalysisContextCollection;
import 'package:analyzer/dart/analysis/results.dart' show ParsedUnitResult;
import 'package:analyzer/dart/analysis/session.dart' show AnalysisSession;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/ast.dart' as dart_ast;
import 'package:analyzer/dart/ast/visitor.dart' as dart_ast_visitor;
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart' show AnalysisError;
import 'package:analyzer/file_system/file_system.dart';

extension _TypeAnnotationExt on TypeAnnotation {
  String getName() {
    String? returnName = type?.getDisplayString(withNullability: false);
    if (returnName == null && this is NamedType) {
      return (this as NamedType).name2.toString();
    }
    return toString();
  }

  Type toType() {
    String typeInString = '';
    List<Type> typeArguments = [];
    List<Type> positionalFields = [];

    if (this is NamedType) {
      typeInString = getName();
      typeArguments = (this as NamedType)
              .typeArguments
              ?.arguments
              .map((ta) => ta.toType())
              .toList() ??
          [];
    } else if (this is RecordTypeAnnotation) {
      final actualTypeAnnotation = this as RecordTypeAnnotation;

      positionalFields = actualTypeAnnotation.positionalFields.map((e) {
        return e.type.toType();
      }).toList();
    }

    return Type()
      ..type = typeInString
      ..isNullable = question != null
      ..typeArguments = typeArguments
      ..positionalFields = positionalFields;
  }
}

class CallApiInvoke {
  late String apiType;
  late String params;
}

class FunctionBody {
  late CallApiInvoke callApiInvoke;
}

class Parameter {
  late DartType? dartType;
  late Type type;
  // List<String> typeArguments = [];
  late String name;
  late bool isNamed;
  late bool isOptional;
  String? defaultValue;
}

extension ParameterExt on Parameter {
  bool get isPrimitiveType =>
      type.type == 'int' ||
      type.type == 'double' ||
      type.type == 'bool' ||
      type.type == 'String' ||
      type.type == 'List' ||
      type.type == 'Map' ||
      type.type == 'Set' ||
      type.type == 'Uint8List';

  String primitiveDefualtValue() {
    switch (type.type) {
      case 'int':
        return '10';
      case 'double':
        return '10.0';
      case 'String':
        return '"hello"';
      case 'bool':
        return 'true';
      case 'List':
        return '[]';
      case 'Map':
        return '{}';
      case 'Uint8List':
        return 'Uint8List.fromList([1, 2, 3, 4, 5])';
      case 'Set':
        return '{}';

      default:
        throw Exception('not support type $type');
    }
  }
}

class Type {
  late String type;
  bool isNullable = false;
  List<Type> typeArguments = [];
  // The parameters associated with the function type.
  List<Parameter> parameters = [];
  // The positional fields of Dart records.
  List<Type> positionalFields = [];
}

extension TypeExt on Type {
  bool get isPrimitiveType =>
      type == 'int' ||
      type == 'double' ||
      type == 'bool' ||
      type == 'String' ||
      type == 'List' ||
      type == 'Map' ||
      type == 'Set';

  String primitiveDefualtValue() {
    switch (type) {
      case 'int':
        return '10';
      case 'double':
        return '10.0';
      case 'String':
        return '"hello"';
      case 'bool':
        return 'true';
      case 'List':
        return '[]';
      case 'Map':
        return '{}';
      case 'Uint8List':
        return 'Uint8List.fromList([])';
      case 'Set':
        return '{}';
      default:
        throw Exception('not support type $type');
    }
  }

  bool isVoid() {
    return type == 'void';
  }

  bool isDartRecords() {
    return positionalFields.isNotEmpty;
  }
}

class SimpleLiteral {
  late String type;
  late String value;
}

class SimpleAnnotation {
  late String name;
  List<SimpleLiteral> arguments = [];
}

class SimpleComment {
  List<String> commentLines = [];
  late int offset;
  late int end;
}

class BaseNode {
  late SimpleComment comment;
  late String source;
  late Uri uri;
}

class Method extends BaseNode {
  late String name;
  late FunctionBody body;
  List<Parameter> parameters = [];
  late Type returnType;
}

class Field extends BaseNode {
  late Type type;
  late String name;
}

class Constructor extends BaseNode {
  late String name;
  List<Parameter> parameters = [];
  late bool isFactory;
  late bool isConst;
}

class Clazz extends BaseNode {
  late String name;
  List<Constructor> constructors = [];
  List<Method> methods = [];
  List<Field> fields = [];
}

class Extensionz extends BaseNode {
  late String name;
  late String extendedType;
  List<Method> methods = [];
  List<Field> fields = [];
}

class EnumConstant extends BaseNode {
  late String name;
  List<SimpleAnnotation> annotations = [];
}

class Enumz extends BaseNode {
  late String name;
  List<EnumConstant> enumConstants = [];
}

class ParseResult {
  late List<Clazz> classes;
  late List<Enumz> enums;
  late List<Extensionz> extensions;

  // TODO(littlegnal): Optimize this later.
  // late Map<String, List<String>> classFieldsMap;
  // late Map<String, String> fieldsTypeMap;
  late Map<String, List<String>> genericTypeAliasParametersMap;
}

extension ParseResultExt on ParseResult {
  bool hasEnum(String type) {
    return enums.any((e) {
      return e.name == type;
    });
  }

  List<Enumz> getEnum(String type, {String? package}) {
    List<Enumz> foundEnums = [];
    for (final enumz in enums) {
      if (package == null) {
        if (enumz.name == type) {
          foundEnums.add(enumz);
        }
      } else {
        if (enumz.name == type &&
            enumz.uri.pathSegments.last.replaceAll('.dart', '') == package) {
          foundEnums.add(enumz);
        }
      }
    }

    return foundEnums;
  }

  bool hasClass(String type) {
    return classes.any((e) => e.name == type);
  }

  List<Clazz> getClazz(String type, {String? package}) {
    List<Clazz> foundClasses = [];
    for (final clazz in classes) {
      if (package == null) {
        if (clazz.name == type) {
          foundClasses.add(clazz);
        }
      } else {
        if (clazz.name == type &&
            clazz.uri.pathSegments.last.replaceAll('.dart', '') == package) {
          foundClasses.add(clazz);
        }
      }
    }

    return foundClasses;
  }

  bool hasExtension(String type) {
    return extensions.any((e) => e.name == type);
  }

  List<Extensionz> getExtension(String type, {String? package}) {
    List<Extensionz> foundExtensions = [];
    for (final extension in extensions) {
      if (package == null) {
        if (extension.name == type) {
          foundExtensions.add(extension);
        }
      } else {
        if (extension.name == type &&
            extension.uri.pathSegments.last.replaceAll('.dart', '') ==
                package) {
          foundExtensions.add(extension);
        }
      }
    }

    return foundExtensions;
  }
}

abstract class DefaultVisitor<R>
    extends dart_ast_visitor.RecursiveAstVisitor<R> {
  /// Called before visiting any node.
  void preVisit(Uri uri) {}

  /// Called after visiting nodes completed.
  void postVisit(Uri uri) {}
}

class DefaultVisitorImpl extends DefaultVisitor<Object?> {
  final classFieldsMap = <String, List<String>>{};
  final fieldsTypeMap = <String, String>{};
  final genericTypeAliasParametersMap = <String, List<String>>{};

  final classMap = <String, Clazz>{};
  final enumMap = <String, Enumz>{};
  final extensionMap = <String, Extensionz>{};

  Uri? _currentVisitUri;

  @override
  void preVisit(Uri uri) {
    _currentVisitUri = uri;
  }

  @override
  void postVisit(Uri uri) {
    _currentVisitUri = null;
  }

  @override
  Object? visitFieldDeclaration(dart_ast.FieldDeclaration node) {
    final clazz = _getClazz(node);
    if (clazz == null) return null;

    final dart_ast.TypeAnnotation? type = node.fields.type;
    final fieldName = node.fields.variables[0].name.toString();
    if (type is dart_ast.NamedType) {
      Field field = Field()
        ..name = fieldName
        ..comment = _generateComment(node)
        ..source = node.toString()
        ..uri = _currentVisitUri!;

      field.type = type.toType();

      clazz.fields.add(field);
    } else if (type is dart_ast.GenericFunctionType) {
      Field field = Field()
        ..name = fieldName
        ..comment = _generateComment(node)
        ..source = node.toString()
        ..uri = _currentVisitUri!;

      Type t = Type()..type = type.functionKeyword.stringValue!;
      t.parameters = _getParameter(null, type.parameters);
      field.type = t;

      clazz.fields.add(field);
    }

    return null;
  }

  @override
  Object? visitConstructorDeclaration(ConstructorDeclaration node) {
    final clazz = _getClazz(node);
    if (clazz == null) return null;

    Constructor constructor = Constructor()
      ..name = node.name?.toString() ?? ''
      ..parameters = _getParameter(node.parent, node.parameters)
      ..isFactory = node.factoryKeyword != null
      ..isConst = node.constKeyword != null
      ..comment = _generateComment(node)
      ..source = node.toSource();

    clazz.constructors.add(constructor);

    return null;
  }

  @override
  Object? visitEnumDeclaration(EnumDeclaration node) {
    final enumz = enumMap.putIfAbsent(node.name.toString(), () => Enumz());
    enumz.name = node.name.toString();
    enumz.comment = _generateComment(node);
    enumz.uri = _currentVisitUri!;

    for (final constant in node.constants) {
      EnumConstant enumConstant = EnumConstant()
        ..name = '${node.name.toString()}.${constant.name.toString()}'
        ..comment = _generateComment(constant)
        ..source = constant.toSource();
      enumz.enumConstants.add(enumConstant);

      for (final meta in constant.metadata) {
        SimpleAnnotation simpleAnnotation = SimpleAnnotation()
          ..name = meta.name.name;
        enumConstant.annotations.add(simpleAnnotation);

        for (final a in meta.arguments?.arguments ?? []) {
          SimpleLiteral simpleLiteral = SimpleLiteral();
          simpleAnnotation.arguments.add(simpleLiteral);

          late String type;
          late String value;

          if (a is IntegerLiteral) {
            type = 'int';
            value = a.value.toString();
          } else if (a is PrefixExpression) {
            if (a.operand is IntegerLiteral) {
              final operand = a.operand as IntegerLiteral;
              type = 'int';
              value = '${a.operator.value()}${operand.value.toString()}';
            }
          } else if (a is BinaryExpression) {
            type = 'int';
            value = a.toSource();
          } else if (a is SimpleStringLiteral) {
            type = 'String';
            value = a.toSource();
          } else if (a is ParenthesizedExpression) {
            if (a.expression.unParenthesized is BinaryExpression ||
                a.expression.unParenthesized is IntegerLiteral) {
              type = 'int';
              value = a.expression.unParenthesized.toSource();
            }
          } else {
            stderr.writeln(
                'Not handled enum: ${enumz.name}, annotation type: ${a.runtimeType}');
          }

          simpleLiteral.type = type;
          simpleLiteral.value = value;
        }
      }
    }

    return null;
  }

  Clazz? _getClazz(AstNode node) {
    final classNode = node.parent;
    if (_currentVisitUri == null ||
        classNode == null ||
        classNode is! dart_ast.ClassDeclaration) {
      return null;
    }

    Clazz clazz = classMap.putIfAbsent(
      '${_currentVisitUri.toString()}#${classNode.name.toString()}',
      () => Clazz()
        ..name = classNode.name.toString()
        ..comment = _generateComment(node as AnnotatedNode)
        ..uri = _currentVisitUri!,
    );

    return clazz;
  }

  List<Parameter> _getParameter(
      AstNode? root, FormalParameterList? formalParameterList) {
    if (formalParameterList == null) return [];
    List<Parameter> parameters = [];
    for (final p in formalParameterList.parameters) {
      Parameter parameter = Parameter();
      Type type = Type();
      parameter.type = type;

      if (p is SimpleFormalParameter) {
        parameter.name = p.name?.toString() ?? '';
        DartType? dartType = p.type?.type;
        parameter.dartType = dartType;

        parameter.type = p.type!.toType();
        parameter.isNamed = p.isNamed;
        parameter.isOptional = p.isOptional;
      } else if (p is DefaultFormalParameter) {
        parameter.name = p.name?.toString() ?? '';
        parameter.defaultValue = p.defaultValue?.toSource();

        DartType? dartType;
        String? typeName;
        List<Type> typeArguments = [];

        if (p.parameter is SimpleFormalParameter) {
          final SimpleFormalParameter simpleFormalParameter =
              p.parameter as SimpleFormalParameter;
          dartType = simpleFormalParameter.type?.type;

          if (simpleFormalParameter.type is NamedType) {
            final namedType = simpleFormalParameter.type as NamedType;
            for (final ta
                in namedType.typeArguments?.arguments ?? <TypeAnnotation>[]) {
              typeArguments.add(ta.toType());
            }

            typeName = (simpleFormalParameter.type as NamedType).getName();
          } else if (simpleFormalParameter.type is GenericFunctionType) {
            typeName = (simpleFormalParameter.type as GenericFunctionType)
                .functionKeyword
                .stringValue;
            type.parameters = _getParameter(null,
                (simpleFormalParameter.type as GenericFunctionType).parameters);
          }
        } else if (p.parameter is FieldFormalParameter) {
          final FieldFormalParameter fieldFormalParameter =
              p.parameter as FieldFormalParameter;

          dartType = fieldFormalParameter.type?.type;

          if (fieldFormalParameter.thisKeyword.stringValue == 'this') {
            if (root != null && root is ClassDeclaration) {
              for (final classMember in root.members) {
                if (classMember is FieldDeclaration) {
                  final dart_ast.TypeAnnotation? fieldType =
                      classMember.fields.type;
                  final fieldName =
                      classMember.fields.variables[0].name.toString();
                  if (fieldType is dart_ast.NamedType) {
                    if (fieldName == fieldFormalParameter.name.toString()) {
                      typeName = fieldType.getName();
                      for (final ta in fieldType.typeArguments?.arguments ??
                          <TypeAnnotation>[]) {
                        typeArguments.add(ta.toType());
                      }
                      break;
                    }
                  } else if (fieldType is dart_ast.GenericFunctionType) {
                    if (fieldName == fieldFormalParameter.name.toString()) {
                      typeName = fieldType.functionKeyword.stringValue;
                      type.parameters =
                          _getParameter(null, fieldType.parameters);

                      break;
                    }
                  }
                }
              }
            }
          } else if (fieldFormalParameter is dart_ast.GenericFunctionType) {
            typeName = (fieldFormalParameter as GenericFunctionType)
                .functionKeyword
                .stringValue;
            type.parameters =
                _getParameter(null, fieldFormalParameter.parameters);

            break;
          }
        }

        parameter.dartType = dartType;
        type.type = typeName!;
        type.typeArguments.addAll(typeArguments);
        parameter.isNamed = p.isNamed;
        parameter.isOptional = p.isOptional;
      } else if (p is FieldFormalParameter) {
        String typeName = '';
        List<Type> typeArguments = [];
        if (root != null && root is ClassDeclaration) {
          for (final classMember in root.members) {
            if (classMember is FieldDeclaration) {
              final dart_ast.TypeAnnotation? fieldType =
                  classMember.fields.type;
              final fieldName = classMember.fields.variables[0].name.toString();
              if (fieldType is dart_ast.NamedType) {
                if (fieldName == p.name.toString()) {
                  typeName = fieldType.toString();
                  for (final ta in fieldType.typeArguments?.arguments ??
                      <TypeAnnotation>[]) {
                    typeArguments.add(ta.toType());
                  }
                  break;
                }
              } else if (fieldType is dart_ast.GenericFunctionType) {
                if (fieldName == p.type?.toString()) {
                  typeName = fieldType.functionKeyword.stringValue ?? '';
                  type.parameters = _getParameter(root, fieldType.parameters);

                  break;
                }
              }
            }
          }
        }

        parameter.name = p.type?.toString() ?? '';
        parameter.dartType = p.type?.type;
        type.type = typeName;
        type.typeArguments.addAll(typeArguments);
        parameter.isNamed = p.isNamed;
        parameter.isOptional = p.isOptional;
      }

      parameters.add(parameter);
    }

    return parameters;
  }

  CallApiInvoke? _getCallApiInvoke(Expression expression) {
    if (expression is! MethodInvocation) return null;

    if (expression.target != null) {
      return _getCallApiInvoke(expression.target!);
    }

    CallApiInvoke callApiInvoke = CallApiInvoke();
    for (final argument in expression.argumentList.arguments) {
      if (argument is SimpleStringLiteral) {
      } else if (argument is FunctionExpression) {
      } else if (argument is SetOrMapLiteral) {
        for (final element in argument.elements) {
          if (element is MapLiteralEntry) {
            final key = (element.key as SimpleStringLiteral).value;
            if (key == 'apiType') {
              callApiInvoke.apiType = element.value.toSource();
            } else if (key == 'params') {
              callApiInvoke.params = element.value.toSource();
            }
          }
        }
      }
    }

    return callApiInvoke;
  }

  SimpleComment _generateComment(AnnotatedNode node) {
    SimpleComment simpleComment = SimpleComment()
      ..offset = node.documentationComment?.offset ?? 0
      ..end = node.documentationComment?.end ?? 0;

    for (final token in node.documentationComment?.tokens ?? []) {
      simpleComment.commentLines.add(token.stringValue ?? '');
    }
    return simpleComment;
  }

  @override
  Object? visitMethodDeclaration(MethodDeclaration node) {
    final clazz = _getClazz(node);
    if (clazz == null) return null;

    clazz.methods.add(_createMethod(node));

    return null;
  }

  Method _createMethod(MethodDeclaration node) {
    Method method = Method()
      ..name = node.name.toString()
      ..source = node.toString()
      ..uri = _currentVisitUri!;

    method.comment = _generateComment(node);

    if (node.parameters != null) {
      method.parameters.addAll(_getParameter(node.parent, node.parameters));
    }

    if (node.returnType != null) {
      method.returnType = node.returnType!.toType();
    }

    if (node.body is BlockFunctionBody) {
      final body = node.body as BlockFunctionBody;

      FunctionBody fb = FunctionBody();
      method.body = fb;
      CallApiInvoke callApiInvoke = CallApiInvoke();
      method.body.callApiInvoke = callApiInvoke;

      for (final statement in body.block.statements) {
        if (statement is ReturnStatement) {
          final returns = statement;

          if (returns.expression != null) {
            CallApiInvoke? callApiInvoke =
                _getCallApiInvoke(returns.expression!);
            if (callApiInvoke != null) {
              method.body.callApiInvoke = callApiInvoke;
            }
          }
        }
      }
    }

    return method;
  }

  @override
  Object? visitGenericTypeAlias(dart_ast.GenericTypeAlias node) {
    final parametersList = node.functionType?.parameters.parameters
            .map((e) {
              if (e is SimpleFormalParameter) {
                return '${e.type} ${e.type?.toString()}';
              }
              return '';
            })
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    genericTypeAliasParametersMap[node.name.toString()] = parametersList;

    return null;
  }

  @override
  Object? visitExtensionDeclaration(dart_ast.ExtensionDeclaration node) {
    extensionMap.putIfAbsent(node.name?.toString() ?? '', () {
      Extensionz extensionz = Extensionz()
        ..name = node.name?.toString() ?? ''
        ..uri = _currentVisitUri!;
      if (node.extendedType is dart_ast.NamedType) {
        extensionz.extendedType = node.extendedType.getName();
      }
      for (final member in node.members) {
        if (member is MethodDeclaration) {
          extensionz.methods.add(_createMethod(member));
        }
      }

      return extensionz;
    });

    return null;
  }
}

class Paraphrase {
  const Paraphrase({
    required this.includedPaths,
    this.excludedPaths,
    this.resourceProvider,
  });

  final List<String> includedPaths;

  final List<String>? excludedPaths;
  final ResourceProvider? resourceProvider;

  ParseResult visit() {
    final DefaultVisitorImpl rootBuilder = DefaultVisitorImpl();

    visitWith(visitor: rootBuilder);

    final parseResult = ParseResult()
      ..classes = rootBuilder.classMap.values.toList()
      ..enums = rootBuilder.enumMap.values.toList()
      ..extensions = rootBuilder.extensionMap.values.toList()
      ..genericTypeAliasParametersMap =
          rootBuilder.genericTypeAliasParametersMap;

    return parseResult;
  }

  void visitWith({
    required DefaultVisitor visitor,
  }) {
    final AnalysisContextCollection collection = AnalysisContextCollection(
      includedPaths: includedPaths,
      excludedPaths: excludedPaths,
      resourceProvider: resourceProvider,
    );

    for (final AnalysisContext context in collection.contexts) {
      for (final String path in context.contextRoot.analyzedFiles()) {
        final AnalysisSession session = context.currentSession;
        final ParsedUnitResult result =
            session.getParsedUnit(path) as ParsedUnitResult;
        if (result.errors.isEmpty) {
          final dart_ast.CompilationUnit unit = result.unit;
          visitor.preVisit(result.uri);
          unit.accept(visitor);
          visitor.postVisit(result.uri);
        } else {
          for (final AnalysisError error in result.errors) {
            stderr.writeln('getParsedUnit error:');
            stderr.writeln(error.toString());
          }
        }
      }
    }
  }
}
