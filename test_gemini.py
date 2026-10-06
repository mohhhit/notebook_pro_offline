import urllib.request
import json
import os
import sys
api_key = os.environ.get('GEMINI_API_KEY')
if not api_key:
    print('No api key')
    sys.exit(0)
url = f'https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key={api_key}'
data = {'model': 'models/text-embedding-004', 'content': {'parts': [{'text': 'Hello world'}]}, 'outputDimensionality': 384}
req = urllib.request.Request(url, data=json.dumps(data).encode('utf-8'), headers={'Content-Type': 'application/json'})
try:
    response = urllib.request.urlopen(req)
    res = json.loads(response.read())
    emb = res['embedding']['values']
    print('Success! Dimensions:', len(emb))
except Exception as e:
    print('Error:', e)

