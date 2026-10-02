"""Register separately generated replacement views without modifying image pixels."""
import argparse
import json
from pathlib import Path
import shutil

from register_directional import BASE, register


def correct(sheet, name, layout, updates):
    assert name.endswith('.png') and Path(name).name == name
    destination = BASE / 'sheets' / name
    if sheet.resolve() != destination.resolve():
        shutil.copyfile(sheet, destination)
    spec_path = BASE / 'sources.json'
    spec = json.loads(spec_path.read_text())
    characters = {item['id']: item for item in spec['characters']}
    for update in updates:
        identity, pairs = update.split('=', 1)
        character = characters[identity]
        source = {'path': 'sheets/' + name, 'layout': layout}
        if source not in character['sheets']:
            character['sheets'].append(source)
        index = character['sheets'].index(source)
        for pair in pairs.split(','):
            angle, cell = map(int, pair.split(':'))
            assert angle in range(0, 360, 30) and 0 <= cell < layout[0] * layout[1]
            character['views'][angle // 30] = [index, cell]
    spec_path.write_text(json.dumps(spec, indent=2) + '\n')
    register()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sheet', required=True, type=Path)
    parser.add_argument('--name', required=True)
    parser.add_argument('--layout', required=True, nargs=2, type=int)
    parser.add_argument('--updates', required=True, nargs='+', help='identity=angle:cell,angle:cell')
    args = parser.parse_args()
    correct(args.sheet, args.name, args.layout, args.updates)
