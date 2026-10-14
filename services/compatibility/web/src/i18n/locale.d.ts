export declare const languages: ['zh-CN', 'en', 'ja'];
export declare function normalizeLanguage(value: unknown): 'zh-CN' | 'en' | 'ja' | null;
export declare function chooseLanguage(query: unknown, saved: unknown, preferred?: readonly unknown[]): 'zh-CN' | 'en' | 'ja';
export declare function translate(source: string, language: string, values?: Record<string, string | number>): string;
