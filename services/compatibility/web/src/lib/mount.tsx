import { StrictMode, type ReactNode } from 'react';
import { createRoot } from 'react-dom/client';
import { CSPProvider } from '@cloudflare/kumo/primitives/csp-provider';
import { TooltipProvider } from '@cloudflare/kumo/components/tooltip';
import { language, t } from '../i18n';
import '../styles.css';

/** Follow the system appearance; Kumo tokens switch through light-dark(). */
function followAppearance(): void {
  const query = matchMedia('(prefers-color-scheme: dark)');
  const apply = () => { document.documentElement.dataset.mode = query.matches ? 'dark' : 'light'; };
  apply();
  query.addEventListener('change', apply);
}

export function mount(title: string, page: ReactNode): void {
  const root = document.documentElement;
  root.lang = language;
  root.dataset.theme = 'fanbar';
  followAppearance();
  document.title = t(title);
  document.body.className = 'bg-kumo-canvas text-kumo-default antialiased';
  createRoot(document.getElementById('root')!).render(
    <StrictMode>
      {/* The CSP allows no inline <style>; the equivalent rules live in styles.css. */}
      <CSPProvider disableStyleElements>
        <TooltipProvider>{page}</TooltipProvider>
      </CSPProvider>
    </StrictMode>,
  );
}
