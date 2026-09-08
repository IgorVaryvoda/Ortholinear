"""Reproducible offline assets. Run with wordfreq==3.1.1, spylls==0.1.7.
No Python, Hunspell engine, source corpus, or network code is shipped in the app.
Generated data retains its separate licenses and provenance inside each asset.
"""
from pathlib import Path
from collections import Counter, defaultdict
import hashlib, json, re, struct, urllib.request, unicodedata, zipfile, tarfile
from importlib.metadata import distribution
from wordfreq import iter_wordlist, zipf_frequency
from spylls.hunspell import Dictionary

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / 'build/suggestion-research'
OUT = ROOT / 'Core/SuggestionData'
CACHE.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
source_manifest = {}

def download(url, name):
    path = CACHE / name
    if not path.exists():
        print('Downloading', url, flush=True)
        path.write_bytes(urllib.request.urlopen(url, timeout=60).read())
    source_manifest[name] = {'url': url, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    return path

def normal(word):
    return unicodedata.normalize('NFC', word).lower().replace('’', "'").replace('ʼ', "'")

def valid(word, lang):
    alphabet = 'a-z' if lang == 'en' else 'а-щьюяєіїґ'
    return 1 <= len(word) <= 24 and re.fullmatch(f"[{alphabet}]+(?:'[{alphabet}]+)*", word) is not None

def hashes(word):
    # Prefix-five symmetric deletes, distance two. Hash collisions are verified at lookup.
    terms = {word[:5]}
    frontier = terms.copy()
    for _ in range(2):
        frontier = {w[:i] + w[i+1:] for w in frontier for i in range(len(w))}
        terms |= frontier
    result = set()
    for term in terms:
        h = 2166136261
        for ch in term:
            h = ((h ^ ord(ch)) * 16777619) & 0xffffffff
        result.add(h)
    return result

ukzip = download('https://github.com/brown-uk/dict_uk/releases/download/v6.8.5/hunspell-uk_UA_6.8.5.zip', 'hunspell-uk_UA_6.8.5.zip')
assert hashlib.sha256(ukzip.read_bytes()).hexdigest() == '25563d417d1c114a9fb9cbca1b23a68289f7c2c7e0d622429b42b1ddededa12a'
with zipfile.ZipFile(ukzip) as archive:
    for name in ['uk_UA.aff', 'uk_UA.dic']:
        (CACHE / name).write_bytes(archive.read(name))

credits = '''Ortholinear suggestion data, 2026. Modified selection, normalization,
frequency scaling, deletion indexes, and pruned n-gram tables by Ortholinear.
Generated lexicon data: CC BY-SA 4.0 https://creativecommons.org/licenses/by-sa/4.0/
Source and regeneration tools: https://github.com/IgorVaryvoda/Ortholinear
Word frequencies: wordfreq 3.1.1, Robyn Speer, https://github.com/rspeer/wordfreq
https://doi.org/10.5281/zenodo.7199437 . Data reflects usage through about 2021.
This is a restricted English/Ukrainian word lookup adaptation, not a general
implementation of wordfreq's multilingual text tokenizer.
English spelling filter: SCOWL dictionary distributed with Spylls 0.1.7.
Ukrainian spelling filter: VESUM Hunspell 6.8.5, Andriy Rysin and contributors,
https://github.com/brown-uk/dict_uk/tree/master/distr/hunspell (MPL 1.1).
The original .aff/.dic dictionaries and the Hunspell/Spylls engines are not bundled.
Context tables: Universal Dependencies 2.18 English EWT (CC BY-SA 4.0) and
UA-GEC (CC BY 4.0), Oleksiy Syvokon, Olena Nahorna, Pavlo Kuchmiichuk,
Nastasiia Osidach, and contributors, Grammarly,
https://github.com/grammarly/ua-gec . Training splits only; pruned counts.
UA-GEC revision: 4757f72f192c4a41e4c8fb1d9690a948f87cf6d6.
Symmetric-delete candidate generation inspired by SymSpell, Wolf Garbe,
https://github.com/wolfgarbe/SymSpell . Native implementation; no port is bundled.
'''
package = distribution('wordfreq')
credits += '\n\n' + package.read_text('LICENSE.txt') + '\n\n' + package.read_text('METADATA').split('## License', 1)[1]
notices = [
    ('wordfreq-NOTICE', 'https://raw.githubusercontent.com/rspeer/wordfreq/42233e6c36ce792031bcccfa17cdd0cec9af5fa7/NOTICE.md'),
    ('SCOWL-Copyright', 'https://raw.githubusercontent.com/en-wl/wordlist/rel-2020.12.07/scowl/Copyright'),
    ('VESUM-Hunspell', 'https://raw.githubusercontent.com/brown-uk/dict_uk/v6.8.5/distr/hunspell/README.md'),
    ('English-EWT-README', 'https://raw.githubusercontent.com/UniversalDependencies/UD_English-EWT/r2.18/README.md'),
    ('UA-GEC-LICENSE', 'https://raw.githubusercontent.com/grammarly/ua-gec/4757f72f192c4a41e4c8fb1d9690a948f87cf6d6/LICENSE'),
    ('UA-GEC-README', 'https://raw.githubusercontent.com/grammarly/ua-gec/4757f72f192c4a41e4c8fb1d9690a948f87cf6d6/README.md'),
    ('English-EWT-LICENSE', 'https://raw.githubusercontent.com/UniversalDependencies/UD_English-EWT/r2.18/LICENSE.txt'),
]
for name, url in notices:
    notice = download(url, name + '.txt').read_text()
    if name == 'UA-GEC-README':
        notice = notice.split('## Citation', 1)[1].split('## Contacts', 1)[0]
    if name == 'English-EWT-README':
        notice = notice.split('# License/Copyright', 1)[1].split('# Structure', 1)[0]
    credits += '\n\n--- ' + name + ' ---\n' + url + '\n' + notice
(OUT / 'DictionaryCredits.txt').write_text(credits)

report = {}
for lang, repository, stem in [('en','UD_English-EWT','en_ewt'), ('uk','UD_Ukrainian-IU','uk_iu')]:
    dictionary = Dictionary.from_files('en_US' if lang == 'en' else str(CACHE / 'uk_UA'))
    words = {}
    # Common, correctly spelled surface forms, including inflections accepted by affix rules.
    for raw in iter_wordlist(lang):
        word = normal(raw)
        if valid(word, lang) and word not in words and (dictionary.lookup(word) or dictionary.lookup(word.capitalize()) or dictionary.lookup(word.upper())):
            words[word] = round(zipf_frequency(raw, lang) * 100)
            if len(words) == 40000: break
    # Explicitly preserve common informal language rather than censoring it.
    for word in ('fuck shit fucking bullshit lol okay yep nope'.split() if lang == 'en' else 'бля блять пиздець хуй нахуй дохуя окей ага'.split()):
        words[word] = max(300, round(zipf_frequency(word, lang) * 100))
    entries = sorted(words.items())
    metadata = json.dumps({'language':lang, 'license':'CC-BY-SA-4.0', 'credits':credits, 'words': entries}, ensure_ascii=False, separators=(',', ':')).encode()
    index = sorted((h, i) for i,(word,_) in enumerate(entries) for h in hashes(word))
    with (OUT / f'{lang}.orthlex').open('wb') as out:
        out.write(b'ORTHLEX1' + struct.pack('<I', len(metadata)) + metadata + struct.pack('<I', len(index)))
        for h,i in index: out.write(struct.pack('<II', h, i))
    print(lang, len(entries), 'words,', len(index), 'index records', flush=True)
    del dictionary, index

    def sentences(split):
        if lang == 'uk':
            archive = download('https://codeload.github.com/grammarly/ua-gec/tar.gz/4757f72f192c4a41e4c8fb1d9690a948f87cf6d6', 'ua-gec-4757f72.tar.gz')
            with tarfile.open(archive) as tar:
                for member in sorted(tar.getmembers(), key=lambda m: m.name):
                    if f'/data/gec-only/{split}/target-sentences/' not in member.name or not member.isfile(): continue
                    if '.a2.' in member.name: continue
                    text = tar.extractfile(member).read().decode('utf-8')
                    for line in text.splitlines():
                        yield [normal(w) for w in re.findall(r"[^\W\d_]+(?:['’ʼ][^\W\d_]+)*|[.!?;:\n]", line)]
            return
        path = download(f'https://raw.githubusercontent.com/UniversalDependencies/{repository}/r2.18/{stem}-ud-{split}.conllu', f'{stem}-{split}.conllu')
        # Use complete surface text to match our runtime apostrophe/token boundaries.
        for line in path.read_text().splitlines():
            if line.startswith('# text = '):
                yield [normal(w) for w in re.findall(r"[^\W\d_]+(?:['’ʼ][^\W\d_]+)*|[.!?;:\n]", line[9:])]
    counts = defaultdict(Counter)
    for sentence in sentences('train'):
        context = []
        for word in sentence:
            if not valid(word, lang):
                context = []
                continue
            if word in words:
                for n in (1, 2):
                    if len(context) >= n: counts[' '.join(context[-n:])][word] += 1
            context.append(word)
    tables = {key: [[word, count] for word,count in counter.most_common(8) if count >= 2]
              for key,counter in sorted(counts.items())}
    tables = {key:value for key,value in tables.items() if value}
    payload = {'license':'CC-BY-SA-4.0', 'credits':credits, 'contexts':tables}
    (OUT / f'{lang}-context.json').write_text(json.dumps(payload,ensure_ascii=False,separators=(',',':')))
    base = [word for word,_ in sorted(words.items(),key=lambda x:(-x[1],x[0]))[:3]]
    scores = Counter()
    for sentence in sentences('test'):
        context = []
        for word in sentence:
            if not valid(word,lang):
                context = []
                continue
            if context:
                choices = tables.get(' '.join(context[-2:]), tables.get(context[-1], []))
                predicted = [entry[0] for entry in choices][:3]
                predicted += [w for w in base if w not in predicted]
                scores['tokens'] += 1
                scores['unigram_hits'] += word in base
                scores['context_hits'] += word in predicted[:3]
                scores['context_available'] += bool(choices)
            context.append(word)
    report[lang] = dict(scores, words=len(words), contexts=len(tables))
    print(lang, report[lang], flush=True)
(CACHE / 'context-benchmark.json').write_text(json.dumps(report,indent=2))

manifest = {'generator': 'Tools/build_suggestion_data.py', 'wordfreq': '3.1.1', 'spylls': '0.1.7', 'sources': source_manifest, 'assets': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.iterdir()) if p.is_file()}}
(ROOT / 'Tools/suggestion-data-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
