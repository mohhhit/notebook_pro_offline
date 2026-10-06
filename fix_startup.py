import re

with open('lib/screens/startup_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

match = re.search(r'      // 2\. Download/Check Embedding Model.*?      // Transition to Main App', content, re.DOTALL)
if not match:
    print("Could not find block")
    exit(1)
start_idx = match.start()
end_idx = match.end() - len('      // Transition to Main App')

new_content = content[:start_idx] + '''      // 2. No local embedding model needed. We use Gemini API.
      setState(() => _statusMessage = 'Initializing...');
      await Future.delayed(const Duration(milliseconds: 500));

      // Transition to Main App
''' + content[end_idx:]

with open('lib/screens/startup_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Done")
