import 'package:test/test.dart';
import 'package:xml/xml.dart';
import 'package:spectra_cli/models/task.dart';

void main() {
  group('SpectraTask', () {
    test('should create with required fields', () {
      final task = SpectraTask(
        id: 'task-001',
        type: 'create',
        name: 'Implement Auth',
        files: ['lib/auth.dart'],
        objective: 'Create authentication module',
        verification: 'Run tests',
        acceptance: 'Auth module exists',
      );

      expect(task.id, equals('task-001'));
      expect(task.type, equals('create'));
      expect(task.name, equals('Implement Auth'));
      expect(task.files, contains('lib/auth.dart'));
      expect(task.objective, equals('Create authentication module'));
    });

    group('XML parsing', () {
      test('fromXml should parse valid XML element', () {
        const xmlString = '''
<task id="task-002" type="modify">
  <n>Update User Model</n>
  <files>
    <file>lib/user.dart</file>
    <file>lib/models/user.dart</file>
  </files>
  <objective>Add email field to user</objective>
  <verification>Check user model has email</verification>
  <acceptance>User model updated</acceptance>
</task>
''';
        final doc = XmlDocument.parse(xmlString);
        final task = SpectraTask.fromXml(doc.rootElement);

        expect(task.id, equals('task-002'));
        expect(task.type, equals('modify'));
        expect(task.name, equals('Update User Model'));
        expect(task.files.length, equals(2));
        expect(task.files, contains('lib/user.dart'));
        expect(task.files, contains('lib/models/user.dart'));
        expect(task.objective, equals('Add email field to user'));
      });

      test('toXml should produce valid XML', () {
        final task = SpectraTask(
          id: 'task-003',
          type: 'create',
          name: 'Create API',
          files: ['lib/api.dart'],
          objective: 'Create REST API',
          verification: 'Run API tests',
          acceptance: 'API endpoints work',
        );

        final xml = task.toXml();

        expect(xml, contains('id="task-003"'));
        expect(xml, contains('type="create"'));
        expect(xml, contains('<n>Create API</n>'));
        expect(xml, contains('<file action="create">lib/api.dart</file>'));
        expect(xml, contains('<objective>Create REST API</objective>'));
      });

      test('round-trip XML serialization should work', () {
        final original = SpectraTask(
          id: 'task-004',
          type: 'modify',
          name: 'Test Task',
          files: ['lib/test.dart'],
          objective: 'Test objective',
          verification: 'Test verification',
          acceptance: 'Test acceptance',
        );

        final xml = original.toXml();
        final doc = XmlDocument.parse(xml);
        final restored = SpectraTask.fromXml(doc.rootElement);

        expect(restored.id, equals(original.id));
        expect(restored.type, equals(original.type));
        expect(restored.name, equals(original.name));
        expect(restored.objective, equals(original.objective));
      });
    });
  });
}
