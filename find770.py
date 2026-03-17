import subprocess
import json

# Get all items with pagination
all_items = []
cursor = None

while True:
    query = f'''
    query {{
      user(login: "tamirdresher_microsoft") {{
        projectV2(number: 1) {{
          items(first: 100{", after: \"" + cursor + "\"" if cursor else ""}) {{
            pageInfo {{
              hasNextPage
              endCursor
            }}
            nodes {{
              id
              content {{
                ... on Issue {{
                  number
                }}
              }}
            }}
          }}
        }}
      }}
    }}
    '''
    
    result = subprocess.run(
        ['gh', 'api', 'graphql', '-f', f'query={query}'],
        capture_output=True,
        text=True
    )
    
    data = json.loads(result.stdout)
    items = data['data']['user']['projectV2']['items']
    
    all_items.extend(items['nodes'])
    
    if not items['pageInfo']['hasNextPage']:
        break
    
    cursor = items['pageInfo']['endCursor']

# Find issue 770
for item in all_items:
    if item.get('content') and item['content'].get('number') == 770:
        print(item['id'])
        break
else:
    print('NOT_FOUND')
