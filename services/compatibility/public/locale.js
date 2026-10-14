import {translations} from './translations.js';
export const languages = ['zh-CN','en','ja'];
export function normalizeLanguage(value) {
  const code=String(value||'').toLowerCase();
  if(code==='zh'||code.startsWith('zh-'))return 'zh-CN';
  if(code==='ja'||code.startsWith('ja-'))return 'ja';
  if(code==='en'||code.startsWith('en-'))return 'en';
  return null;
}
export function chooseLanguage(query, saved, preferred=[]) {
  return normalizeLanguage(query)||normalizeLanguage(saved)||preferred.map(normalizeLanguage).find(Boolean)||'en';
}
export function translate(source, language, values={}) {
  const key=Object.hasOwn(translations,source)?source:source.trim();
  const entry=translations[key];
  let result=language==='zh-CN'?(entry?.['zh-CN']||source):(entry?.[language]||source);
  for(const [name,value]of Object.entries(values))result=result.replaceAll('{'+name+'}',String(value));
  return result;
}
