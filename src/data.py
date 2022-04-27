import json
import requests

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
            content_type = title_map[item_type]
            name = name_from[content_type]['default']['content']
            tiles = item['image']['tile']
            available_aspect_ratios = list(tiles)
            ratios = list([i, float(i)] for i in tiles)
            ratios.sort(key=lambda x: abs(x[1] - ASPECT_RATIO))
            closest_aspect_ratio = ratios[0][0]

            if content_type not in tiles[closest_aspect_ratio]:
                tile_url = (
                    tiles[closest_aspect_ratio]['default']['default']['url']
                )
            else:
                tile_url = (
                    tiles[closest_aspect_ratio][content_type]['default']['url']
                )

            print('   ', name, f'"{tile_url[:15]}..."')

            # slug_from = item['text']['title']['slug']
            # slug = name_from[title_map[item_type]]['default']['content']
    else:
        ref_id = set_['refId']
        request = requests.get(
            f'https://cd-static.bamgrid.com/dp-117731241344/sets/{ref_id}.json'
        )

        try:
            items = request.json()['data'][set_['contentClass']]
        except:
            print(set_.keys(), set_['contentClass'], set_['refIdType'], set_['refType'], set_['type'])
            print(request.json()['data'].keys())
            print(set_)
            print()
            raise

        for item in items['items']:
            item_type = item['type']
            name_from = item['text']['title']['full']
            content_type = title_map[item_type]
            name = name_from[content_type]['default']['content']
            tiles = item['image']['tile']
            available_aspect_ratios = list(tiles)
            ratios = list([i, float(i)] for i in tiles)
            ratios.sort(key=lambda x: abs(x[1] - ASPECT_RATIO))
            closest_aspect_ratio = ratios[0][0]
            break
