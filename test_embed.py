import urllib.request
import json
import sys

def check():
    api_key = ''
    if not api_key:
        print('No API key')
        return
    url = f'https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key={api_key}'
    data = {
        'model': 'models/text-embedding-004',
        'content': {'parts': [{'text': 'Hello world'}]},
        'outputDimensionality': 384
    }
    req = urllib.request.Request(url, data=json.dumps(data).encode('utf-8'), headers={'Content-Type': 'application/json'})
    try:
        response = urllib.request.urlopen(req)
        print('Success!')
    except urllib.error.HTTPError as e:
        print('HTTP Error:', e.code, e.read().decode())
    except Exception as e:
        print('Error:', e)
check()
