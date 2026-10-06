import re

with open('lib/providers/app_state.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the modelPath definition
content = re.sub(r'      final appDir = await getApplicationDocumentsDirectory\(\);\s*final modelPath = \'\$\{appDir\.path\}/models/all-MiniLM-L6-v2\.tflite\';', '', content)

# Remove modelPath from the args passing
content = content.replace('          modelPath: modelPath,', '')

with open('lib/providers/app_state.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
