import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:paraphrase/paraphrase.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  late FileSystem fileSystem;
  late OverlayResourceProvider resourceProvider;

  setUp(() {
    fileSystem = MemoryFileSystem();
    resourceProvider =
        OverlayResourceProvider(PhysicalResourceProvider.INSTANCE);
  });

  test('Parse function fields', () {
    final file = fileSystem.file('event_handler.dart');
    file.createSync();
    file.writeAsStringSync('''
class RtcEngineEventHandler {
  const RtcEngineEventHandler({
    this.onError,
    this.onAudioQuality,
  });
  final void Function(int err, String msg)? onError;

  final void Function(int uid, int quality)? onAudioQuality;
}
''');

    resourceProvider.setOverlay(
      file.absolute.path,
      content: file.readAsStringSync(),
      modificationStamp: file.lastModifiedSync().millisecondsSinceEpoch,
    );

    final paraphrase = Paraphrase(
      includedPaths: [file.absolute.path],
      resourceProvider: resourceProvider,
    );
    final parseResult = paraphrase.visit();

    expect(parseResult.classes.length, 1);

    final clazz = parseResult.classes[0];

    expect(clazz.constructors.length, 1);
    expect(clazz.constructors[0].parameters.length, 2);

    final constructor = clazz.constructors[0];

    expect(constructor.parameters[0].name, 'onError');
    expect(constructor.parameters[0].type.type, 'Function');
    expect(constructor.parameters[0].type.parameters.length, 2);
    expect(constructor.parameters[0].type.parameters[0].name, 'err');
    expect(constructor.parameters[0].type.parameters[0].type.type, 'int');
    expect(constructor.parameters[0].type.parameters[1].name, 'msg');
    expect(constructor.parameters[0].type.parameters[1].type.type, 'String');

    expect(constructor.parameters[1].name, 'onAudioQuality');
    expect(constructor.parameters[1].type.type, 'Function');
    expect(constructor.parameters[1].type.parameters.length, 2);
    expect(constructor.parameters[1].type.parameters[0].name, 'uid');
    expect(constructor.parameters[1].type.parameters[0].type.type, 'int');
    expect(constructor.parameters[1].type.parameters[1].name, 'quality');
    expect(constructor.parameters[1].type.parameters[1].type.type, 'int');

    expect(clazz.fields.length, 2);

    expect(clazz.fields[0].name, 'onError');
    expect(clazz.fields[0].type.type, 'Function');
    expect(clazz.fields[0].type.parameters.length, 2);
    expect(clazz.fields[0].type.parameters[0].name, 'err');
    expect(clazz.fields[0].type.parameters[0].type.type, 'int');
    expect(clazz.fields[0].type.parameters[1].name, 'msg');
    expect(clazz.fields[0].type.parameters[1].type.type, 'String');

    expect(clazz.fields[1].name, 'onAudioQuality');
    expect(clazz.fields[1].type.type, 'Function');
    expect(clazz.fields[1].type.parameters.length, 2);
    expect(clazz.fields[1].type.parameters[0].name, 'uid');
    expect(clazz.fields[1].type.parameters[0].type.type, 'int');
    expect(clazz.fields[1].type.parameters[1].name, 'quality');
    expect(clazz.fields[1].type.parameters[1].type.type, 'int');
  });

  test('Parse function parameter in constructor', () {
    final file = fileSystem.file('event_handler.dart');
    file.createSync();
    file.writeAsStringSync('''
class RtcEngineEventHandler {
  const RtcEngineEventHandler({
    final void Function(int err, String msg)? onError,
  });
}
''');
  
    resourceProvider.setOverlay(
      file.absolute.path,
      content: file.readAsStringSync(),
      modificationStamp: file.lastModifiedSync().millisecondsSinceEpoch,
    );

    final paraphrase = Paraphrase(
      includedPaths: [file.absolute.path],
      resourceProvider: resourceProvider,
    );
    final parseResult = paraphrase.visit();

    expect(parseResult.classes.length, 1);

    final clazz = parseResult.classes[0];

    expect(clazz.constructors.length, 1);
    expect(clazz.constructors[0].parameters.length, 1);

    final constructor = clazz.constructors[0];

    expect(constructor.parameters[0].name, 'onError');
    expect(constructor.parameters[0].type.type, 'Function');
    expect(constructor.parameters[0].type.parameters.length, 2);
    expect(constructor.parameters[0].type.parameters[0].name, 'err');
    expect(constructor.parameters[0].type.parameters[0].type.type, 'int');
    expect(constructor.parameters[0].type.parameters[1].name, 'msg');
    expect(constructor.parameters[0].type.parameters[1].type.type, 'String');

    // expect(constructor.parameters[1].name, 'onAudioQuality');
    // expect(constructor.parameters[1].type.type, 'Function');
    // expect(constructor.parameters[1].type.parameters.length, 2);
    // expect(constructor.parameters[1].type.parameters[0].name, 'uid');
    // expect(constructor.parameters[1].type.parameters[0].type.type, 'int');
    // expect(constructor.parameters[1].type.parameters[1].name, 'quality');
    // expect(constructor.parameters[1].type.parameters[1].type.type, 'int');

    // expect(clazz.fields.length, 2);

    // expect(clazz.fields[0].name, 'onError');
    // expect(clazz.fields[0].type.type, 'Function');
    // expect(clazz.fields[0].type.parameters.length, 2);
    // expect(clazz.fields[0].type.parameters[0].name, 'err');
    // expect(clazz.fields[0].type.parameters[0].type.type, 'int');
    // expect(clazz.fields[0].type.parameters[1].name, 'msg');
    // expect(clazz.fields[0].type.parameters[1].type.type, 'String');

    // expect(clazz.fields[1].name, 'onAudioQuality');
    // expect(clazz.fields[1].type.type, 'Function');
    // expect(clazz.fields[1].type.parameters.length, 2);
    // expect(clazz.fields[1].type.parameters[0].name, 'uid');
    // expect(clazz.fields[1].type.parameters[0].type.type, 'int');
    // expect(clazz.fields[1].type.parameters[1].name, 'quality');
    // expect(clazz.fields[1].type.parameters[1].type.type, 'int');
  });
}
