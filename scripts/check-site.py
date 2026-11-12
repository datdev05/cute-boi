"""Check local asset references and extract inline JS for node --check."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

root = Path('nho-em/dist').resolve()

class SiteParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.in_script = False
        self.scripts = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            assert attrs['id'] not in self.ids, f"Duplicate ID: {attrs['id']}"
            self.ids.add(attrs['id'])
        for key in ('src', 'href'):
            value = attrs.get(key, '')
            url = urlsplit(value)
            if not value or url.scheme or url.netloc or not url.path:
                continue
            asset = (root / unquote(url.path).lstrip('/')).resolve()
            assert asset.is_relative_to(root), f'Asset outside site: {value}'
            assert asset.is_file(), f'Missing asset: {value}'
        if tag == 'script':
            self.in_script = 'src' not in attrs

    def handle_endtag(self, tag):
        if tag == 'script':
            self.in_script = False

    def handle_data(self, data):
        if self.in_script:
            self.scripts.append(data)

parser = SiteParser()
parser.feed((root / 'index.html').read_text())
Path('/tmp/cute-boi-inline.js').write_text('\n;\n'.join(parser.scripts))
print('HTML asset references and element IDs: OK')
