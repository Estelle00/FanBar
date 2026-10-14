import { cn } from '@cloudflare/kumo/utils';
import { t } from '../i18n';
import type { Tone } from '../lib/labels';

const toneClass: Record<Tone, string> = {
  ok: 'text-kumo-success',
  pending: 'text-kumo-warning',
  mixed: 'text-fanbar-mixed',
  absent: 'text-kumo-subtle',
  unknown: 'text-kumo-subtle',
  unsupported: 'text-kumo-danger',
};

/** Shape and colour both encode the result, so it reads without colour too. */
export function StatusIcon({ tone, className }: { tone: Tone; className?: string }) {
  return (
    <svg viewBox="0 0 16 16" aria-hidden="true" className={cn('size-3.5 shrink-0', toneClass[tone], className)}>
      {tone === 'ok' && (
        <>
          <circle cx="8" cy="8" r="6.6" fill="currentColor" fillOpacity=".14" stroke="currentColor" strokeOpacity=".45" />
          <path d="M5 8.2l2 2 4-4.3" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
        </>
      )}
      {tone === 'pending' && (
        <>
          <circle cx="8" cy="8" r="6.3" fill="none" stroke="currentColor" strokeWidth="1.5" />
          <path d="M8 4.7v4" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
          <circle cx="8" cy="11" r=".95" fill="currentColor" />
        </>
      )}
      {tone === 'mixed' && (
        <>
          <circle cx="8" cy="8" r="6.3" fill="none" stroke="currentColor" strokeWidth="1.5" />
          <path d="M8 1.7a6.3 6.3 0 0 0 0 12.6z" fill="currentColor" />
        </>
      )}
      {tone === 'absent' && (
        <>
          <circle cx="8" cy="8" r="6.3" fill="none" stroke="currentColor" strokeWidth="1.5" />
          <path d="M5 8h6" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
        </>
      )}
      {tone === 'unknown' && <circle cx="8" cy="8" r="6.3" fill="none" stroke="currentColor" strokeWidth="1.5" strokeDasharray="2.4 2.2" />}
      {tone === 'unsupported' && (
        <>
          <circle cx="8" cy="8" r="6.3" fill="none" stroke="currentColor" strokeWidth="1.5" />
          <path d="M5.6 5.6l4.8 4.8M10.4 5.6l-4.8 4.8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
        </>
      )}
    </svg>
  );
}

export function StatusLabel({ tone, label, className }: { tone: Tone; label: string; className?: string }) {
  return (
    <span className={cn('inline-flex items-center gap-1.5 font-medium text-kumo-default', className)}>
      <StatusIcon tone={tone} />
      {label}
    </span>
  );
}

/** 3: developer verification · 2: 10 or more reports · 1: 1–9 reports · 0: none */
export const evidenceLevel = (reports: number, verified: boolean): number => (verified ? 3 : reports >= 10 ? 2 : reports > 0 ? 1 : 0);

export function EvidenceBars({ level }: { level: number }) {
  return (
    <span className="inline-flex gap-0.5 align-middle" role="img" aria-label={t('证据等级 {level}/3', { level })}>
      {[1, 2, 3].map(index => (
        <i key={index} className={cn('h-2.75 w-1 rounded-[1px]', index <= level ? 'bg-kumo-contrast' : 'bg-kumo-fill')} />
      ))}
    </span>
  );
}
