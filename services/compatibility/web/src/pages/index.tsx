import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react';
import { Banner } from '@cloudflare/kumo/components/banner';
import { Button } from '@cloudflare/kumo/components/button';
import { Empty } from '@cloudflare/kumo/components/empty';
import { Input } from '@cloudflare/kumo/components/input';
import { LayerCard } from '@cloudflare/kumo/components/layer-card';
import { Loader } from '@cloudflare/kumo/components/loader';
import { Table } from '@cloudflare/kumo/components/table';
import { cn } from '@cloudflare/kumo/utils';
import { ArrowSquareOutIcon, MagnifyingGlassIcon, WarningCircleIcon, XIcon } from '@phosphor-icons/react';
import { DataTable } from '../components/data-table';
import { Page, PageTitle, SiteHeader, TextLink } from '../components/shell';
import { EvidenceBars, StatusLabel, evidenceLevel } from '../components/status';
import { t } from '../i18n';
import { api, type Capability, type Matrix, type MatrixGroup } from '../lib/api';
import { capabilityOrder, capabilityTitle, errorMessage, modelTitle, statusTitle, toneOf, type Tone } from '../lib/labels';
import { mount } from '../lib/mount';

/* ---------- Deriving a cell from the public API ---------- */
type Cell = ReturnType<typeof cellOf>;

function cellOf(group: MatrixGroup, capability: Capability) {
  const rows = group.community.filter(row => row.capability === capability).sort((a, b) => b.count - a.count);
  const confirmations = rows.reduce((sum, row) => sum + (row.userConfirmedWorking ?? 0), 0);
  const total = rows.reduce((sum, row) => sum + row.count, 0);
  const verification = group.developerVerifications.find(row => row.capability === capability);
  let tone: Tone;
  let label: string;
  if (verification) { tone = toneOf(verification.status); label = statusTitle(verification.status); }
  else if (rows.length === 0) { tone = 'unknown'; label = t('暂无报告'); }
  else if (confirmations === total && total > 0) { tone = 'ok'; label = t('本机实测可用（用户确认）'); }
  else if (rows.length === 1) { tone = toneOf(rows[0].status); label = statusTitle(rows[0].status); }
  else { tone = 'mixed'; label = t('结果不一致'); }
  return { rows, total, confirmations, verification, tone, label, level: evidenceLevel(total, Boolean(verification)) };
}

const groupKey = (group: MatrixGroup) => [group.modelIdentifier, group.macOSVersion, group.appVersion, group.helperVersion].join('|');

const toneFill: Record<Tone, string> = {
  ok: 'bg-kumo-success', pending: 'bg-kumo-warning', mixed: 'bg-fanbar-mixed',
  absent: 'bg-kumo-interact', unknown: 'bg-kumo-fill', unsupported: 'bg-kumo-danger',
};

const legend: [Tone, string][] = [
  ['ok', '可用'], ['mixed', '结果不一致'], ['pending', '请求成功，待实测'],
  ['absent', '未读取'], ['unknown', '暂无证据'], ['unsupported', '实测不支持'],
];

/* ---------- Page ---------- */
function CompatibilityPage() {
  const [model, setModel] = useState('');
  const [path, setPath] = useState('/api/compatibility');
  const [data, setData] = useState<Matrix | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selected, setSelected] = useState<{ key: string; capability: Capability } | null>(null);

  const load = useCallback(async (query: string) => {
    const next = '/api/compatibility' + (query ? '?model=' + encodeURIComponent(query) : '');
    setPath(next);
    setLoading(true);
    setError(null);
    try {
      setData(await api<Matrix>(next));
      setSelected(null);
    } catch (failure) {
      setError(errorMessage(failure));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void load(''); }, [load]);

  const models = useMemo(() => {
    const byModel = new Map<string, MatrixGroup[]>();
    for (const group of data?.groups ?? []) byModel.set(group.modelIdentifier, [...(byModel.get(group.modelIdentifier) ?? []), group]);
    return [...byModel.entries()];
  }, [data]);

  const selectedGroup = selected ? data?.groups.find(group => groupKey(group) === selected.key) : undefined;

  const submit = (event: FormEvent) => {
    event.preventDefault();
    void load(model.trim());
  };

  return (
    <>
      <SiteHeader
        subtitle="设备兼容性 · 公开记录"
        links={[
          { href: '/privacy.html', label: '收集与处理规则' },
          { href: '/withdraw.html', label: '撤回报告' },
          { href: 'https://github.com/helson-lin/FanBar', label: '查看源码 ↗', external: true },
        ]}
      />
      <Page>
        <PageTitle
          title="这台 Mac，能使用哪些功能？"
          lede="查看经过审核的社区报告与开发者实测记录。温度读取、风扇读取和实际控制分别判断；没有记录不代表不支持。"
        />

        <LayerCard className="mb-5">
          <LayerCard.Primary>
          <form onSubmit={submit} className="flex flex-row flex-wrap items-end gap-3">
            <div className="min-w-64 flex-1">
              <Input
                label={t('机型标识')}
                placeholder={t('输入机型标识，例如 Mac14,13')}
                maxLength={64}
                value={model}
                onChange={event => setModel(event.target.value)}
                className="w-full font-mono"
              />
            </div>
            <Button type="submit" variant="primary" icon={MagnifyingGlassIcon} loading={loading}>{t('查询')}</Button>
            <a href={path} target="_blank" rel="noopener" className="inline-flex h-9 items-center gap-1 px-1 text-[13px] text-kumo-link no-underline hover:underline">
              {t('公开 JSON ↗')}
            </a>
          </form>
        </LayerCard.Primary>
        </LayerCard>

        <div className="mb-3 flex flex-wrap items-center gap-x-4 gap-y-1.5 text-xs text-kumo-subtle">
          {legend.map(([tone, label]) => <StatusLabel key={tone} tone={tone} label={t(label)} className="font-normal text-kumo-subtle" />)}
          <span className="h-3.5 w-px bg-kumo-hairline" />
          <span className="inline-flex items-center gap-1.5"><EvidenceBars level={3} />{t('开发者实测')}</span>
          <span className="inline-flex items-center gap-1.5"><EvidenceBars level={2} />{t('≥10 份报告')}</span>
          <span className="inline-flex items-center gap-1.5"><EvidenceBars level={1} />{t('1–9 份报告')}</span>
        </div>

        {error && (
          <Banner
            variant="error"
            icon={<WarningCircleIcon weight="fill" />}
            title={t('暂时无法加载记录，请重试。')}
            description={error}
            action={<Button size="sm" onClick={() => void load(model.trim())}>{t('查询')}</Button>}
          />
        )}

        {!error && loading && !data && (
          <LayerCard><LayerCard.Primary className="flex items-center gap-2 py-10 text-sm text-kumo-subtle"><Loader />{t('正在加载公开记录…')}</LayerCard.Primary></LayerCard>
        )}

        {!error && data && models.length === 0 && (
          <LayerCard>
            <LayerCard.Primary>
              <Empty
                icon={<MagnifyingGlassIcon size={40} className="text-kumo-inactive" />}
                title={t('此组合暂无公开记录')}
                description={t('可先参考 FanBar 的本机检测结果；在应用中主动提交报告，帮助完善兼容性记录。')}
              />
            </LayerCard.Primary>
          </LayerCard>
        )}

        {!error && models.length > 0 && (
          <div className="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_340px]">
            <div className="flex min-w-0 flex-col gap-4">
              {models.map(([identifier, groups]) => (
                <ModelMatrix
                  key={identifier}
                  identifier={identifier}
                  groups={groups}
                  selected={selected}
                  onSelect={(key, capability) => setSelected({ key, capability })}
                />
              ))}
            </div>
            <div className="lg:sticky lg:top-4">
              {selectedGroup && selected
                ? <EvidencePanel group={selectedGroup} capability={selected.capability} onClose={() => setSelected(null)} />
                : (
                  <LayerCard>
                    <LayerCard.Primary className="text-sm text-kumo-subtle">{t('点击表格中的任一格，查看结果分布与依据。')}</LayerCard.Primary>
                  </LayerCard>
                )}
            </div>
          </div>
        )}

        <p className="mt-3 text-xs text-kumo-subtle" role="status">
          {loading ? t('正在查询…') : data && !error ? (data.truncated ? t('当前显示最近 20 个版本组合，输入机型标识缩小范围。') : t('已显示当前有效记录。')) : ''}
        </p>

        <div className="mt-8 grid gap-4 md:grid-cols-3">
          {[
            ['社区报告', '用户主动提交并经审核的检测结果。统计为报告数量，不代表独立设备数量，也不会自动成为开发者验证。'],
            ['开发者验证', '对应机型、系统与软件版本的独立实测，附带验证日期和公开依据。控制请求成功不等于实际转速已验证。'],
            ['隐私与撤回', '原始报告默认私有。选择公开的报告也需审核后才可查阅；可以使用本机保存的撤回凭证删除报告及其统计贡献。'],
          ].map(([title, body]) => (
            <LayerCard key={title}>
              <LayerCard.Secondary>{t(title)}</LayerCard.Secondary>
              <LayerCard.Primary className="text-[13px] leading-relaxed text-kumo-subtle">{t(body)}</LayerCard.Primary>
            </LayerCard>
          ))}
        </div>

        <footer className="mt-10 flex flex-wrap items-center justify-between gap-3 border-t border-kumo-hairline pt-4 text-xs text-kumo-subtle">
          <span>{t('报告在线保留 90 天，公开统计随有效报告变化。')}</span>
          <span className="flex gap-3">
            <TextLink href="/report-schema.json" label="完整字段 Schema" />
            <TextLink href="/privacy.html" label="处理规则" />
            <TextLink href="/admin/" label="管理入口" />
          </span>
        </footer>
      </Page>
    </>
  );
}

/* ---------- Capability × version matrix for one model ---------- */
function ModelMatrix({ identifier, groups, selected, onSelect }: {
  identifier: string;
  groups: MatrixGroup[];
  selected: { key: string; capability: Capability } | null;
  onSelect: (key: string, capability: Capability) => void;
}) {
  const reports = groups.reduce((sum, group) => sum + group.community.reduce((count, row) => count + row.count, 0), 0) / capabilityOrder.length;
  const verifications = groups.reduce((sum, group) => sum + group.developerVerifications.length, 0);
  return (
    <LayerCard className="p-0">
      <LayerCard.Secondary className="flex flex-wrap items-center gap-x-5 gap-y-1">
        <span className="text-base font-semibold text-kumo-default">{modelTitle(identifier)}</span>
        <span className="font-mono text-xs font-normal text-kumo-subtle">{identifier}</span>
        <span className="text-xs font-normal text-kumo-subtle tabular">{t('reportCount', { count: Math.round(reports) })}</span>
        {verifications > 0 && <span className="text-xs font-normal text-kumo-subtle tabular">{t('开发者实测 {count} 项', { count: verifications })}</span>}
      </LayerCard.Secondary>
      <LayerCard.Primary className="overflow-x-auto p-0">
        <DataTable>
          <Table.Header>
            <Table.Row>
              <Table.Head className="w-40">{t('能力')}</Table.Head>
              {groups.map(group => (
                <Table.Head key={groupKey(group)} className="min-w-48">
                  <span className="block text-kumo-default">macOS {group.macOSVersion}</span>
                  <span className="block font-normal">FanBar {group.appVersion} · Helper {group.helperVersion}</span>
                  <span className="block font-normal tabular">{t('更新 ')}{group.updatedOn}</span>
                </Table.Head>
              ))}
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {capabilityOrder.map(capability => (
              <Table.Row key={capability} className="!bg-kumo-base">
                <Table.Cell>{capabilityTitle(capability)}</Table.Cell>
                {groups.map(group => {
                  const key = groupKey(group);
                  const cell = cellOf(group, capability);
                  const active = selected?.key === key && selected.capability === capability;
                  return (
                    <Table.Cell key={key} className="!p-0">
                      <button
                        type="button"
                        aria-pressed={active}
                        aria-label={`${capabilityTitle(capability)} · macOS ${group.macOSVersion} · ${cell.label}`}
                        onClick={() => onSelect(key, capability)}
                        className={cn(
                          'flex w-full items-center justify-between gap-3 px-4 py-2.5 text-left outline-none transition-colors hover:bg-kumo-tint',
                          'focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-kumo-focus',
                          active && 'bg-kumo-info-tint ring-2 ring-inset ring-kumo-brand',
                        )}
                      >
                        <StatusLabel tone={cell.tone} label={cell.label} className="whitespace-nowrap" />
                        <CellCount cell={cell} />
                      </button>
                    </Table.Cell>
                  );
                })}
              </Table.Row>
            ))}
          </Table.Body>
        </DataTable>
      </LayerCard.Primary>
    </LayerCard>
  );
}

function CellCount({ cell }: { cell: Cell }) {
  const text = cell.total === 0 ? '—' : cell.rows.length > 1 ? `${cell.rows[0].count}/${cell.total}` : t('reportCount', { count: cell.total });
  return (
    <span className="inline-flex items-center gap-2 whitespace-nowrap text-xs text-kumo-subtle tabular">
      {text}
      <EvidenceBars level={cell.level} />
    </span>
  );
}

/* ---------- Evidence for one cell ---------- */
const explanation: Record<Tone, string> = {
  ok: '报告结果一致，可以作为参考。',
  pending: '系统接受了控制请求，但还没有证据证明风扇转速确实改变。',
  mixed: '存在不同结果，请结合版本与本机检测判断。',
  absent: '报告中没有成功读取或执行。这不等于已证实不支持。',
  unknown: '目前没有报告，也没有开发者实测。',
  unsupported: '开发者实测确认在此版本组合下不可用。',
};

function EvidencePanel({ group, capability, onClose }: { group: MatrixGroup; capability: Capability; onClose: () => void }) {
  const cell = cellOf(group, capability);
  return (
    <LayerCard className="p-0">
      <LayerCard.Secondary className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="truncate text-xs font-normal text-kumo-subtle">
            <span className="font-mono">{modelTitle(group.modelIdentifier)} · {group.modelIdentifier}</span> · macOS {group.macOSVersion} · FanBar {group.appVersion}
          </p>
          <p className="text-base font-semibold text-kumo-default">{capabilityTitle(capability)}</p>
        </div>
        <Button variant="ghost" size="sm" shape="square" icon={XIcon} aria-label={t('关闭')} onClick={onClose} />
      </LayerCard.Secondary>
      <LayerCard.Primary className="flex flex-col p-0 text-[13px]">
        <section className="border-b border-kumo-hairline p-4">
          <div className="flex items-center justify-between gap-3">
            <StatusLabel tone={cell.tone} label={cell.label} className="text-sm" />
            <span className="inline-flex items-center gap-1.5 text-xs text-kumo-subtle tabular">
              <EvidenceBars level={cell.level} />
              {t('reportCount', { count: cell.total })}
            </span>
          </div>
          <p className="mt-2 leading-relaxed text-kumo-subtle">
            {t(cell.verification && cell.tone === 'ok' ? '开发者已在对应版本实机验证。' : cell.confirmations > 0 ? '用户确认在本机实际使用可用，不等同于开发者独立实测。' : explanation[cell.tone])}
          </p>
        </section>

        {cell.total > 0 && (
          <section className="border-b border-kumo-hairline p-4">
            <p className="mb-2 text-xs font-semibold text-kumo-subtle">{t('社区报告')}</p>
            {cell.confirmations > 0 && <p className="mb-2 text-xs text-kumo-subtle">{t('用户确认本机实测可用：{count} 份报告', { count: cell.confirmations })}</p>}
            <div className="mb-2.5 flex h-2 overflow-hidden rounded-full bg-kumo-fill">
              {cell.rows.map(row => (
                <Segment key={row.status} className={toneFill[toneOf(row.status)]} share={row.count / cell.total} />
              ))}
            </div>
            <ul className="flex flex-col gap-1.5">
              {cell.rows.map(row => (
                <li key={row.status} className="flex items-center justify-between">
                  <StatusLabel tone={toneOf(row.status)} label={statusTitle(row.status)} className="font-normal" />
                  <span className="text-kumo-subtle tabular">{t('reportCount', { count: row.count })}</span>
                </li>
              ))}
            </ul>
            <p className="mt-2.5 text-xs text-kumo-subtle">{t('报告数是份数，不是设备数。')}</p>
          </section>
        )}

        <section className="p-4">
          <p className="mb-2 text-xs font-semibold text-kumo-subtle">{t('开发者验证')}</p>
          {cell.verification ? (
            <div className="flex flex-col gap-1.5">
              <StatusLabel tone={toneOf(cell.verification.status)} label={statusTitle(cell.verification.status)} />
              <p className="leading-relaxed text-kumo-default">{cell.verification.notes}</p>
              <a
                href={cell.verification.source_url}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1 text-kumo-link no-underline hover:underline"
              >
                {t('依据 · ')}{cell.verification.verified_on}
                <ArrowSquareOutIcon size={12} />
              </a>
            </div>
          ) : (
            <p className="text-kumo-subtle">{t('尚未实测')}</p>
          )}
        </section>
      </LayerCard.Primary>
    </LayerCard>
  );
}

/** React applies style props through the CSSOM, which the CSP permits (unlike style attributes in markup). */
function Segment({ className, share }: { className: string; share: number }) {
  return <i className={cn('h-full', className)} style={{ width: `${share * 100}%` }} />;
}

mount('FanBar · 公开兼容性记录', <CompatibilityPage />);
