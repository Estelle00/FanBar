import type { ComponentProps } from 'react';
import { Table } from '@cloudflare/kumo/components/table';
import { cn } from '@cloudflare/kumo/utils';

/** Kumo Table at FanBar density: compact rows and small neutral headings. */
export function DataTable({ className, ...props }: ComponentProps<typeof Table>) {
  return (
    <Table
      {...props}
      className={cn(
        'text-[13px] [&_td]:px-4 [&_td]:py-2.5 [&_th]:px-4 [&_th]:py-2 [&_th]:text-xs [&_th]:font-medium',
        '[&_th]:text-kumo-subtle [&_th]:bg-kumo-elevated [&_th]:border-kumo-hairline',
        className,
      )}
    />
  );
}
