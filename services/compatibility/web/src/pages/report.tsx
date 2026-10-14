import { useEffect, useState } from 'react';
import { Banner } from '@cloudflare/kumo/components/banner';
import { Collapsible } from '@cloudflare/kumo/components/collapsible';
import { LayerCard } from '@cloudflare/kumo/components/layer-card';
import { Loader } from '@cloudflare/kumo/components/loader';
import { Table } from '@cloudflare/kumo/components/table';
import { WarningCircleIcon } from '@phosphor-icons/react';
import { DataTable } from '../components/data-table';
import { Page, PageTitle, SiteHeader } from '../components/shell';
import { StatusLabel } from '../components/status';
import { t } from '../i18n';
import { api, type PublicReport } from '../lib/api';
import { capabilityOrder, capabilityTitle, errorMessage, modelTitle, statusTitle, toneOf } from '../lib/labels';
import { mount } from '../lib/mount';

function ReportPage() {
  const id = new URL(location.href).searchParams.get('id') ?? '';
  const valid = /^[0-9a-f-]{36}$/i.test(id);
  const [data, setData] = useState<PublicReport | null>(null);
  const report = data?.report;
  const [error, setError] = useState<string | null>(valid ? null : t('无效的报告编号。'));

  useEffect(() => {
    if (!valid) return;
    api<PublicReport>('/api/reports/' + encodeURIComponent(id)).then(setData, failure => setError(errorMessage(failure)));
  }, [id, valid]);

  const byCapability = new Map(report?.capabilities.map(row => [row.capability, row]));

  return (
    <>
      <SiteHeader subtitle="用户选择公开的社区报告" links={[{ href: '/privacy.html', label: '处理规则' }]} />
      <Page width="prose">
        <PageTitle title="公开兼容性报告" lede="此报告由用户选择公开，并经审核。它不等同于开发者实测。" />
        {error && <Banner variant="error" icon={<WarningCircleIcon weight="fill" />} description={error} />}
        {!error && !report && <p className="flex items-center gap-2 text-sm text-kumo-subtle"><Loader />{t('正在查询…')}</p>}
        {report && (
          <LayerCard className="p-0">
            <LayerCard.Secondary className="flex flex-col items-stretch gap-1">
              <span className="text-base font-semibold text-kumo-default">{modelTitle(report.device.modelIdentifier)}</span>
              <span className="font-mono text-xs text-kumo-subtle">{report.device.modelIdentifier}</span>
              <span className="text-xs font-normal text-kumo-subtle">
                {report.device.processor} · macOS {report.device.macOSVersion} · FanBar {report.device.appVersion} · Helper {report.device.helperVersion}
              </span>
              <span className="text-xs font-normal text-kumo-subtle" role="status">{t('用户自愿公开 · 社区报告')} · {t('接收于 {date}', { date: data!.receivedOn })}</span>
            </LayerCard.Secondary>
            <LayerCard.Primary className="p-0">
              <DataTable>
                <Table.Header>
                  <Table.Row>
                    <Table.Head>{t('能力')}</Table.Head>
                    <Table.Head>{t('报告结果')}</Table.Head>
                    <Table.Head>{t('原因码')}</Table.Head>
                  </Table.Row>
                </Table.Header>
                <Table.Body>
                  {capabilityOrder.map(capability => {
                    const row = byCapability.get(capability);
                    return (
                      <Table.Row key={capability}>
                        <Table.Cell>{capabilityTitle(capability)}</Table.Cell>
                        <Table.Cell>{row && <span className="flex flex-col gap-1">
                            <StatusLabel tone={row.userConfirmedWorking ? 'ok' : toneOf(row.status)} label={row.userConfirmedWorking ? t('本机实测可用（用户确认）') : statusTitle(row.status)} />
                            {row.userConfirmedWorking && <span className="text-xs text-kumo-subtle">{t('自动检测：{status}', { status: statusTitle(row.status) })}</span>}
                          </span>}</Table.Cell>
                        <Table.Cell className="font-mono text-xs text-kumo-subtle">{row?.reasonCode}</Table.Cell>
                      </Table.Row>
                    );
                  })}
                </Table.Body>
              </DataTable>
              <div className="border-t border-kumo-hairline px-4 py-3">
                <Collapsible.Root>
                  <Collapsible.DefaultTrigger>{t('原始字段')}</Collapsible.DefaultTrigger>
                  <Collapsible.DefaultPanel>
                    <pre className="mt-2 overflow-auto rounded-md bg-kumo-recessed p-3 font-mono text-xs leading-relaxed text-kumo-default">{JSON.stringify(data, null, 2)}</pre>
                  </Collapsible.DefaultPanel>
                </Collapsible.Root>
              </div>
            </LayerCard.Primary>
          </LayerCard>
        )}
      </Page>
    </>
  );
}

mount('公开报告 · FanBar', <ReportPage />);
