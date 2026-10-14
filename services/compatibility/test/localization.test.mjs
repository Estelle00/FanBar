import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile, readdir} from 'node:fs/promises';
import {translations} from '../web/src/i18n/translations.js';
import {chooseLanguage,translate} from '../web/src/i18n/locale.js';

const source = new URL('../web/src/', import.meta.url);
// Native language names are shown as-is in every interface language.
const untranslated = new Set(['简体中文', '日本語', '语言', '言語']);
const cjk = /[぀-ヿ一-鿿]/;

async function sources() {
  const files = (await readdir(source, {recursive: true})).filter(file => /\.(tsx?)$/.test(file) && !file.startsWith('i18n'));
  return Promise.all(files.map(async file => {
    const code = await readFile(new URL(file, source), 'utf8');
    // Comments are documentation, not interface text.
    return [file, code.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '').replace(/([^:])\/\/ .*$/gm, '$1')];
  }));
}

test('explicit language wins, regional locales normalize, unsupported languages fall back',()=>{
  assert.equal(chooseLanguage('ja','en',['zh-TW']),'ja');
  assert.equal(chooseLanguage(null,'en',['ja-JP']),'en');
  assert.equal(chooseLanguage(null,null,['fr-FR','ja-JP']),'ja');
  assert.equal(chooseLanguage(null,null,['zh-HK']),'zh-CN');
  assert.equal(chooseLanguage('invalid',null,['fr-FR']),'en');
});

test('every Chinese interface string in the React source has English and Japanese translations',async()=>{
  let checked = 0;
  for (const [file, code] of await sources()) {
    for (const match of code.matchAll(/(['"`])((?:\\.|(?!\1)[^\\])*?)\1/g)) {
      const text = match[2];
      if (!cjk.test(text) || untranslated.has(text)) continue;
      checked++;
      assert.ok(translations[text]?.en, `${file}: missing English: ${text}`);
      assert.ok(translations[text]?.ja, `${file}: missing Japanese: ${text}`);
    }
  }
  assert.ok(checked > 150, `expected to find the interface strings, found ${checked}`);
});

test('JSX never renders Chinese text without translation',async()=>{
  for (const [file, code] of await sources()) {
    if (!file.endsWith('.tsx')) continue;
    for (const match of code.matchAll(/>([^<>{}]*)</g)) {
      assert.ok(!cjk.test(match[1]), `${file}: untranslated JSX text: ${match[1].trim()}`);
    }
  }
});

test('placeholders keep counts and pages',()=>{
  assert.equal(translate('reportCount','en',{count:3}),'3 reports');
  assert.equal(translate('pageNumber','ja',{page:2}),'2 ページ');
  assert.equal(translate('pageNumber','zh-CN',{page:2}),'第 2 页');
});
