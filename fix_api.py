import codecs
import re

with codecs.open('lib/services/api_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

with codecs.open('inject.txt', 'r', encoding='utf-8') as f:
    inject = f.read()

match = re.search(r'  Stream<ChatStreamEvent> sendMessageStream\(.*?  \}', content, re.DOTALL)
start_idx = match.start()

match2 = re.search(r'  // ==================== File Upload ====================', content)
end_idx = match2.start()

new_content = content[:start_idx] + inject + content[end_idx:]

with codecs.open('lib/services/api_service.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Replaced perfectly")
