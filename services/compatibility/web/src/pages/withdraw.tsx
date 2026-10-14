import { useState, type FormEvent } from 'react';
import { Banner } from '@cloudflare/kumo/components/banner';
import { Button } from '@cloudflare/kumo/components/button';
import { Input } from '@cloudflare/kumo/components/input';
import { LayerCard } from '@cloudflare/kumo/components/layer-card';
import { CheckCircleIcon, WarningCircleIcon } from '@phosphor-icons/react';
import { Page, PageTitle, SiteHeader } from '../components/shell';
import { t } from '../i18n';
import { api } from '../lib/api';
import { errorMessage } from '../lib/labels';
import { mount } from '../lib/mount';

function WithdrawPage() {
  const [id, setId] = useState('');
  const [token, setToken] = useState('');
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<{ ok: boolean; text: string } | null>(null);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    const reportID = id.trim();
    const credential = token.trim();
    if (!/^[0-9a-f-]{36}$/i.test(reportID) || !/^[A-Za-z0-9_-]{43}$/.test(credential)) {
      setResult({ ok: false, text: t('请检查报告编号和撤回凭证。') });
      return;
    }
    setBusy(true);
    try {
      // The credential travels only in a request header; it never enters the URL or browser storage.
      await api('/api/reports/' + encodeURIComponent(reportID), { method: 'DELETE', headers: { Authorization: 'Bearer ' + credential } });
      setResult({ ok: true, text: t('报告已撤回，或已经过期。') });
      setToken('');
    } catch (error) {
      setResult({ ok: false, text: errorMessage(error) });
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <SiteHeader subtitle="设备兼容性 · 撤回报告" links={[{ href: '/privacy.html', label: '处理规则' }]} />
      <Page width="prose">
        <PageTitle title="撤回你提交的报告" lede="也可以在 FanBar 的上报记录中撤回。删除后，报告不再被公开查询，也不再计入在线社区统计。" />
        <LayerCard>
          <LayerCard.Primary>
          <form onSubmit={submit} className="flex flex-col gap-4">
            <Input label={t('报告编号')} required maxLength={36} autoComplete="off" className="w-full font-mono" value={id} onChange={event => setId(event.target.value)} />
            <Input
              label={t('撤回凭证')}
              type="password"
              required
              maxLength={43}
              autoComplete="off"
              className="w-full font-mono"
              description={t('凭证只通过加密请求发送，不写入网址或浏览器存储。请勿将凭证放进公开反馈。')}
              value={token}
              onChange={event => setToken(event.target.value)}
            />
            <div>
              <Button type="submit" variant="primary" loading={busy}>{t('确认撤回报告')}</Button>
            </div>
            <div role="status">
              {result && (
                <Banner
                  variant={result.ok ? 'default' : 'error'}
                  icon={result.ok ? <CheckCircleIcon weight="fill" /> : <WarningCircleIcon weight="fill" />}
                  description={result.text}
                />
              )}
            </div>
          </form>
        </LayerCard.Primary>
        </LayerCard>
        <p className="mt-4 text-xs text-kumo-subtle">{t('在线删除不代表云平台历史恢复点立即清除，详见处理规则。')}</p>
      </Page>
    </>
  );
}

mount('撤回报告 · FanBar', <WithdrawPage />);
