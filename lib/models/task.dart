import 'package:xml/xml.dart';

class SpectraTask {
  final String id;
  final String type;
  final String name;
  final List<String> files;
  final String objective;
  final String verification;
  final String acceptance;

  SpectraTask({
    required this.id,
    required this.type,
    required this.name,
    required this.files,
    required this.objective,
    required this.verification,
    required this.acceptance,
  });

  factory SpectraTask.fromXml(XmlElement element) {
    return SpectraTask(
      id: element.getAttribute('id') ?? '',
      type: element.getAttribute('type') ?? '',
      name: element.findElements('n').first.innerText,
      files: element
          .findElements('files')
          .first
          .findElements('file')
          .map((f) => f.innerText)
          .toList(),
      objective: element.findElements('objective').first.innerText,
      verification: element.findElements('verification').first.innerText,
      acceptance: element.findElements('acceptance').first.innerText,
    );
  }

  String toXml() {
    return '''
<task id="$id" type="$type">
  <n>$name</n>
  <files>${files.map((f) => '<file action="create">$f</file>').join()}</files>
  <objective>$objective</objective>
  <verification>$verification</verification>
  <acceptance>$acceptance</acceptance>
</task>''';
  }
}
