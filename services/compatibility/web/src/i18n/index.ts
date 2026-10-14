import { translations } from './translations.js';
import { chooseLanguage, translate } from './locale.js';

export type Language = 'zh-CN' | 'en' | 'ja';
const storageKey = 'fanbar-report-language';

let saved: string | null = null;
try { saved = localStorage.getItem(storageKey); } catch { /* Storage is optional. */ }

export const language: Language = chooseLanguage(
  new URL(location.href).searchParams.get('lang'), saved, navigator.languages ?? [navigator.language],
);

export const t = (source: string, values: Record<string, string | number> = {}): string => translate(source, language, values);
export const hasTranslation = (source: string): boolean => Object.hasOwn(translations, source);

export const languageNames: Record<Language, string> = { 'zh-CN': '简体中文', en: 'English', ja: '日本語' };

export function switchLanguage(next: Language): void {
  try { localStorage.setItem(storageKey, next); } catch { /* The query parameter keeps the choice without storage. */ }
  const url = new URL(location.href);
  url.searchParams.set('lang', next);
  location.assign(url.href);
}

/** Preserve the language choice on same-origin page links, even when storage is unavailable. */
export function localized(href: string): string {
  const url = new URL(href, location.href);
  if (url.origin !== location.origin || url.pathname.startsWith('/api/') || url.pathname.endsWith('.json')) return href;
  url.searchParams.set('lang', language);
  return url.pathname + url.search + url.hash;
}
