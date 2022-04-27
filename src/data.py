import json

js = json.load(open('home.json'))['data']['StandardCollection']['containers']

title_map = {
    'DmcSeries': 'series',
    'DmcVideo': 'program',
    'StandardCollection': 'collection',
}

SCREEN_WIDTH = 1920
SCREEN_HEIGHT = 1080
ASPECT_RATIO = SCREEN_HEIGHT / SCREEN_WIDTH

for container in js:
    set_ = container['set']

    set_type = set_['type']
    set_name = set_['text']['title']['full']['set']['default']['content']

    print({'Name': set_name, 'Type': set_type})

    if set_['type'] == 'CuratedSet':
        for item in set_['items']:
            item_type = item['type']
            name_from = item['text']['title']['full']
            name = name_from[title_map[item_type]]['default']['content']

            available_aspect_ratios = list(item['image']['tile'])

            ratios = list([i, float(i)] for i in item['image']['tile'])

            ratios.sort(key=lambda x: abs(x[1] - ASPECT_RATIO))

            closest_aspect_ratio = ratios[0][0]

            print('   ', name, closest_aspect_ratio)

            # slug_from = item['text']['title']['slug']
            # slug = name_from[title_map[item_type]]['default']['content']


            # image =

            # print('   ', name, '->', image)
            # print('   ', name, f'"{slug}"')
