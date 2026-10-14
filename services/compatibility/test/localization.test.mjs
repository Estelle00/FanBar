import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {translations} from '../public/translations.js';
import {chooseLanguage,translate} from '../public/locale.js';
test('explicit language wins, regional locales normalize, unsupported languages fall back',()=>{
  assert.equal(chooseLanguage('ja','en',['zh-TW']),'ja');
  assert.equal(chooseLanguage(null,'en',['ja-JP']),'en');
  assert.equal(chooseLanguage(null,null,['fr-FR','ja-JP']),'ja');
  assert.equal(chooseLanguage(null,null,['zh-HK']),'zh-CN');
  assert.equal(chooseLanguage('invalid',null,['fr-FR']),'en');
});
test('every authored static string and placeholder has English and Japanese translations',async()=>{
  for(const file of ['index','privacy','admin','withdraw','report']){
    const html=await readFile(new URL('../public/'+file+'.html',import.meta.url),'utf8');
    const strings=[...html.matchAll(/>([^<>]+)</g)].map(m=>m[1].trim());
    strings.push(...[...html.matchAll(/placeholder="([^"]+)"/g)].map(m=>m[1]));
    for(const source of strings.filter(s=>/[\u4e00-\u9fff]/.test(s))){
      assert.ok(translations[source]?.en,`${file}: missing English: ${source}`);
      assert.ok(translations[source]?.ja,`${file}: missing Japanese: ${source}`);
    }
  }
});
test('dynamic labels have translations and preserve counts',async()=>{
  for(const file of ['common','matrix','admin','withdraw','report']){
    const js=await readFile(new URL('../public/'+file+'.js',import.meta.url),'utf8');
    for(const match of js.matchAll(/t\(("(?:[^"\\]|\\.)*")/g)){
      const source=JSON.parse(match[1]).trim();
      assert.ok(translations[source]||translations[JSON.parse(match[1])],`${file}: ${source}`);
    }
  }
  assert.equal(translate('reportCount','en',{count:3}),'3 reports');
  assert.equal(translate('pageNumber','ja',{page:2}),'2 ページ');
  assert.equal(translate('pageNumber','zh-CN',{page:2}),'第 2 页');
});
