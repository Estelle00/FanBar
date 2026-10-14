import {translations} from './translations.js';
import {chooseLanguage,translate} from './locale.js';
let saved=null;
try{saved=localStorage.getItem('fanbar-report-language');}catch{/* Storage is optional. */}
export const language=chooseLanguage(new URL(location.href).searchParams.get('lang'),saved,navigator.languages||[navigator.language]);
export const t=(source,values={})=>translate(source,language,values);
function initialize() {
  document.documentElement.lang=language;
  const walker=document.createTreeWalker(document.documentElement,NodeFilter.SHOW_TEXT);
  const nodes=[];while(walker.nextNode())nodes.push(walker.currentNode);
  for(const node of nodes){if(node.parentElement?.closest('script,style,pre'))continue;const source=node.textContent;const trimmed=source.trim();if(Object.hasOwn(translations,trimmed))node.textContent=source.replace(trimmed,t(trimmed));}
  for(const node of document.querySelectorAll('[placeholder]'))node.setAttribute('placeholder',t(node.getAttribute('placeholder')));
  const nav=document.querySelector('header nav');
  if(nav){const label=document.createElement('label');label.className='language-picker';label.textContent=({en:'Language',ja:'言語','zh-CN':'语言'})[language];const select=document.createElement('select');select.setAttribute('aria-label',label.textContent);for(const [code,title]of [['zh-CN','简体中文'],['en','English'],['ja','日本語']]){const option=document.createElement('option');option.value=code;option.textContent=title;option.selected=code===language;select.append(option);}select.addEventListener('change',()=>{try{localStorage.setItem('fanbar-report-language',select.value);}catch{/* Query parameter keeps selection without storage. */}const url=new URL(location.href);url.searchParams.set('lang',select.value);location.assign(url.href);});label.append(select);nav.append(label);}
  // Preserve a choice across pages even when browser storage is unavailable.
  for(const link of document.querySelectorAll('a[href]')){const url=new URL(link.getAttribute('href'),location.href);if(url.origin===location.origin&&!url.pathname.startsWith('/api/')&&!url.pathname.endsWith('.json')){url.searchParams.set('lang',language);link.href=url.href;}}
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',initialize,{once:true});else initialize();
