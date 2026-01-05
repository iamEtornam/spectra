/// Generates the full HTML document with embedded styles and scripts.
///
/// Wraps Jaspr-rendered component HTML in a complete document with
/// auto-refresh functionality for real-time monitoring.
String wrapInDocument(String bodyHtml) {
  return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Spectra Dashboard</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }
    code {
      background: #1a1f2e;
      padding: 0.2rem 0.4rem;
      border-radius: 4px;
      font-family: inherit;
    }
  </style>
</head>
<body>
$bodyHtml
<script>
  // Auto-refresh every 2 seconds for real-time monitoring
  setTimeout(function() {
    window.location.reload();
  }, 2000);
</script>
</body>
</html>
''';
}
