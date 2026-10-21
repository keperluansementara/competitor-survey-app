import { useEffect, useMemo, useState, type FormEvent } from 'react';
import type { Session } from '@supabase/supabase-js';
import {
  Activity,
  AlertTriangle,
  ArrowUpRight,
  BarChart3,
  Boxes,
  CalendarDays,
  CheckCircle2,
  ClipboardCheck,
  Database,
  FileSpreadsheet,
  History,
  LayoutDashboard,
  LogOut,
  RefreshCw,
  Search,
  Settings,
  ShieldCheck,
  Store,
  Users,
} from 'lucide-react';
import { loadAdminDashboardMetrics, type AdminDashboardMetrics } from './lib/admin-dashboard';
import { supabase } from './lib/supabase';

type AppRole = 'admin' | 'supervisor' | 'surveyor' | 'analyst';
type Profile = { id: string; display_name: string; role: AppRole; active: boolean; employee_identifier: string | null };

const navItems = [
  { id: 'dashboard', label: 'Ringkasan', icon: LayoutDashboard, description: 'Status campaign, review, kualitas data, dan sinkronisasi.' },
  { id: 'outlets', label: 'Outlet & import', icon: Store, description: 'Master outlet, template impor, pratinjau validasi, dan pemulihan.' },
  { id: 'masters', label: 'Master data', icon: Boxes, description: 'Wilayah, channel, kategori, brand, SKU, kemasan, dan unit.' },
  { id: 'forms', label: 'Form survei', icon: ClipboardCheck, description: 'Susun, pratinjau, publikasikan, dan arsipkan versi form.' },
  { id: 'users', label: 'Pengguna', icon: Users, description: 'Role, status akun, cakupan wilayah, dan akses campaign.' },
  { id: 'campaigns', label: 'Campaign', icon: CalendarDays, description: 'Periode, SKU, target outlet, penugasan, dan progres petugas.' },
  { id: 'quality', label: 'Review & kualitas', icon: ShieldCheck, description: 'Review supervisor, anomali, kelengkapan, dan revisi.' },
  { id: 'sync', label: 'Sinkronisasi', icon: RefreshCw, description: 'Penerimaan data dari perangkat dan status bukti foto.' },
  { id: 'reports', label: 'Laporan', icon: BarChart3, description: 'Filter dan ekspor data pengamatan yang diizinkan.' },
  { id: 'audit', label: 'Audit & pengaturan', icon: History, description: 'Riwayat perubahan dan aturan operasional.' },
] as const;

type NavId = (typeof navItems)[number]['id'];

const emptyMetrics: AdminDashboardMetrics = {
  campaignName: null,
  targets: 0,
  completed: 0,
  pendingReview: 0,
  needsRevision: 0,
  qualityAlerts: 0,
  lastSyncAt: null,
};

function LoginScreen({ onSignedIn }: { onSignedIn: (session: Session) => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!supabase) return;
    setBusy(true);
    setError(null);
    const { data, error: signInError } = await supabase.auth.signInWithPassword({ email, password });
    setBusy(false);
    if (signInError) {
      setError('Email atau kata sandi tidak cocok. Pastikan akun pilot sudah dibuat oleh admin.');
      return;
    }
    if (data.session) onSignedIn(data.session);
  };

  return (
    <main className="login-page">
      <section className="login-card">
        <div className="logo-mark"><Activity size={22} aria-hidden="true" /></div>
        <p className="eyebrow">MARKET INTEL · PILOT DEPO TANGERANG UTARA</p>
        <h1>Masuk ke pusat kendali</h1>
        <p className="muted">Gunakan akun kerja yang telah dibuat oleh admin.</p>
        <form onSubmit={submit} className="login-form">
          <label htmlFor="email">Email kerja</label>
          <input id="email" type="email" autoComplete="username" required value={email} onChange={(event) => setEmail(event.target.value)} />
          <label htmlFor="password">Kata sandi</label>
          <input id="password" type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} />
          {error && <p className="inline-error" role="alert">{error}</p>}
          <button className="button button-primary full-width" type="submit" disabled={busy}>{busy ? 'Memeriksa akun…' : 'Masuk'}</button>
        </form>
        <p className="login-footnote">Akses data ditentukan oleh role dan RLS database.</p>
      </section>
    </main>
  );
}

function MetricCard({ label, value, helper, icon: Icon, tone = 'green' }: {
  label: string;
  value: string | number;
  helper: string;
  icon: typeof Store;
  tone?: 'green' | 'amber' | 'red' | 'blue';
}) {
  return (
    <article className="metric-card">
      <div className={`metric-icon tone-${tone}`}><Icon size={19} aria-hidden="true" /></div>
      <p className="metric-label">{label}</p>
      <p className="metric-value">{value}</p>
      <p className="metric-helper">{helper}</p>
    </article>
  );
}

function Dashboard({ metrics, onNavigate }: { metrics: AdminDashboardMetrics; onNavigate: (id: NavId) => void }) {
  const completedPercent = metrics.targets > 0 ? Math.min(100, Math.round((metrics.completed / metrics.targets) * 100)) : 0;
  const syncText = metrics.lastSyncAt
    ? new Intl.DateTimeFormat('id-ID', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(metrics.lastSyncAt))
    : 'Belum ada data sinkronisasi';

  return (
    <>
      <div className="page-heading">
        <div><p className="eyebrow">PILOT · DEPO TANGERANG UTARA</p><h1>Ringkasan operasional</h1><p className="muted">Metrik ini dihitung dari data yang dapat diakses akun Anda.</p></div>
        <button className="button button-secondary" onClick={() => onNavigate('campaigns')}><CalendarDays size={17} />{metrics.campaignName ?? 'Pilih campaign'}<ArrowUpRight size={15} /></button>
      </div>

      {!metrics.campaignName && <div className="notice notice-neutral"><Database size={18} /><span>Belum ada campaign aktif. Angka target aktif akan muncul dari database setelah campaign dibuat.</span></div>}

      <section className="metric-grid" aria-label="Metrik dashboard">
        <MetricCard label="Target outlet" value={metrics.targets.toLocaleString('id-ID')} helper={metrics.campaignName ?? 'Campaign aktif'} icon={Store} />
        <MetricCard label="Survei selesai" value={metrics.completed.toLocaleString('id-ID')} helper={`${completedPercent}% dari target aktif`} icon={CheckCircle2} tone="blue" />
        <MetricCard label="Menunggu review" value={metrics.pendingReview.toLocaleString('id-ID')} helper="Submitted atau sedang ditinjau" icon={ClipboardCheck} tone="amber" />
        <MetricCard label="Perlu revisi" value={metrics.needsRevision.toLocaleString('id-ID')} helper="Dikembalikan oleh supervisor" icon={RefreshCw} tone="red" />
        <MetricCard label="Peringatan kualitas" value={metrics.qualityAlerts.toLocaleString('id-ID')} helper="Flag terbuka, bukan penghapusan otomatis" icon={AlertTriangle} tone="amber" />
        <MetricCard label="Sinkronisasi terakhir" value={syncText} helper="Receipt server terakhir yang tercatat" icon={Activity} tone="blue" />
      </section>

      <section className="dashboard-lower">
        <article className="panel progress-panel">
          <div className="panel-heading"><div><p className="eyebrow">PROGRES CAMPAIGN</p><h2>{metrics.campaignName ?? 'Belum ada campaign aktif'}</h2></div><button className="icon-button" title="Buka campaign" onClick={() => onNavigate('campaigns')}><ArrowUpRight size={18} /></button></div>
          <div className="progress-meta"><span>Survei selesai</span><strong>{metrics.completed.toLocaleString('id-ID')} <span className="muted">/ {metrics.targets.toLocaleString('id-ID')}</span></strong></div>
          <div className="progress-track" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={completedPercent}><span style={{ width: `${completedPercent}%` }} /></div>
          <p className="muted small-copy">Progres dihitung dari status assignment di database.</p>
        </article>
        <article className="panel action-panel">
          <div className="panel-heading"><div><p className="eyebrow">TINDAKAN ADMIN</p><h2>Akses cepat</h2></div></div>
          <button className="quick-action" onClick={() => onNavigate('outlets')}><span className="quick-icon"><FileSpreadsheet size={18} /></span><span><strong>Kelola outlet & import</strong><small>Unduh template atau periksa import</small></span><ArrowUpRight size={16} /></button>
          <button className="quick-action" onClick={() => onNavigate('campaigns')}><span className="quick-icon"><CalendarDays size={18} /></span><span><strong>Atur campaign</strong><small>Target outlet dan penugasan</small></span><ArrowUpRight size={16} /></button>
          <button className="quick-action" onClick={() => onNavigate('users')}><span className="quick-icon"><Users size={18} /></span><span><strong>Kelola akses pengguna</strong><small>Role, wilayah, dan campaign</small></span><ArrowUpRight size={16} /></button>
        </article>
      </section>
    </>
  );
}

function ModulePlaceholder({ activeNav, onNavigate }: { activeNav: NavId; onNavigate: (id: NavId) => void }) {
  const selected = navItems.find((item) => item.id === activeNav) ?? navItems[0];
  const Icon = selected.icon;
  return (
    <section className="module-placeholder panel">
      <div className="placeholder-icon"><Icon size={26} /></div>
      <p className="eyebrow">MODUL ADMIN</p>
      <h1>{selected.label}</h1>
      <p className="muted">{selected.description}</p>
      {activeNav === 'outlets' && <div className="template-links"><a href="/templates/outlet_master_template.csv" download>Unduh template master outlet</a><a href="/templates/campaign_assignment_template.csv" download>Unduh template penugasan campaign</a></div>}
      <p className="placeholder-note">Modul ini disiapkan dalam increment berikutnya. Tidak ada data operasional contoh yang ditampilkan di sini.</p>
      <button className="button button-primary" onClick={() => onNavigate('dashboard')}>Kembali ke ringkasan</button>
    </section>
  );
}

function AdminApp({ profile, onSignOut }: { profile: Profile; onSignOut: () => void }) {
  const [activeNav, setActiveNav] = useState<NavId>('dashboard');
  const [metrics, setMetrics] = useState<AdminDashboardMetrics>(emptyMetrics);
  const [metricsState, setMetricsState] = useState<'loading' | 'ready' | 'error'>('loading');
  const [metricsError, setMetricsError] = useState('');
  const [refreshing, setRefreshing] = useState(false);
  const activeItem = useMemo(() => navItems.find((item) => item.id === activeNav) ?? navItems[0], [activeNav]);

  const refresh = async () => {
    if (!supabase) return;
    setRefreshing(true);
    setMetricsError('');
    try {
      const nextMetrics = await loadAdminDashboardMetrics(supabase);
      setMetrics(nextMetrics);
      setMetricsState('ready');
    } catch (error) {
      setMetricsState('error');
      setMetricsError(error instanceof Error ? error.message : 'Metrik tidak dapat dimuat.');
    } finally {
      setRefreshing(false);
    }
  };

  useEffect(() => { void refresh(); }, []);

  return (
    <div className="admin-layout">
      <aside className="sidebar">
        <div className="sidebar-brand"><div className="logo-mark small-logo"><Activity size={18} /></div><span>Market Intel<small>ADMIN CONTROL CENTER</small></span></div>
        <p className="nav-section-label">WORKSPACE</p>
        <nav className="side-nav" aria-label="Navigasi utama">
          {navItems.map(({ id, label, icon: Icon }) => <button key={id} className={`nav-link ${activeNav === id ? 'selected' : ''}`} onClick={() => setActiveNav(id)}><Icon size={18} /><span>{label}</span></button>)}
        </nav>
        <div className="sidebar-footer"><div className="user-avatar">{profile.display_name.slice(0, 1).toUpperCase()}</div><div className="user-summary"><strong>{profile.display_name}</strong><span>Admin · Depo Tangerang Utara</span></div><button className="icon-button logout-button" onClick={onSignOut} title="Keluar"><LogOut size={17} /></button></div>
      </aside>

      <div className="workspace">
        <header className="topbar">
          <div className="mobile-brand"><div className="logo-mark small-logo"><Activity size={17} /></div><strong>Market Intel</strong></div>
          <div className="breadcrumbs"><span>Admin</span><span>/</span><strong>{activeItem.label}</strong></div>
          <div className="topbar-actions"><span className="pilot-pill"><span />Pilot development</span><button className="icon-button" title="Cari"><Search size={18} /></button><button className="icon-button" title="Riwayat" onClick={() => setActiveNav('audit')}><History size={18} /></button><button className="icon-button mobile-logout" title="Keluar" onClick={onSignOut}><LogOut size={17} /></button></div>
        </header>

        <nav className="mobile-nav" aria-label="Navigasi admin">
          {navItems.map(({ id, label, icon: Icon }) => <button key={id} className={activeNav === id ? 'selected' : ''} onClick={() => setActiveNav(id)}><Icon size={17} /><span>{label}</span></button>)}
        </nav>

        <main className="page-content">
          {activeNav === 'dashboard' && <>
            <div className="content-toolbar"><div><span className="live-dot" />Data dashboard dari Supabase</div><button className="button button-secondary" onClick={() => void refresh()} disabled={refreshing}><RefreshCw size={16} className={refreshing ? 'spin' : ''} />{refreshing ? 'Memuat…' : 'Muat ulang'}</button></div>
            {metricsState === 'loading' && <div className="notice notice-neutral"><Database size={18} /><span>Mengambil metrik yang diizinkan dari database…</span></div>}
            {metricsState === 'error' && <div className="notice notice-error"><AlertTriangle size={18} /><span>Metrik belum dapat dimuat dari Supabase: {metricsError}. Periksa koneksi, grants, dan RLS.</span></div>}
            {metricsState === 'ready' && <Dashboard metrics={metrics} onNavigate={setActiveNav} />}
          </>}
          {activeNav !== 'dashboard' && <ModulePlaceholder activeNav={activeNav} onNavigate={setActiveNav} />}
        </main>
        <footer className="workspace-footer"><span>Market Intelligence · Development</span><span><Settings size={14} /> Akses mengikuti role dan kebijakan database</span></footer>
      </div>
    </div>
  );
}

export default function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [authState, setAuthState] = useState<'loading' | 'signed-out' | 'signed-in' | 'unconfigured'> (supabase ? 'loading' : 'unconfigured');
  const [profile, setProfile] = useState<Profile | null>(null);
  const [profileState, setProfileState] = useState<'loading' | 'ready' | 'missing' | 'error'>('loading');
  const [profileError, setProfileError] = useState('');

  useEffect(() => {
    if (!supabase) return;
    let alive = true;
    const { data: listener } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      if (!alive) return;
      setSession(nextSession);
      setAuthState(nextSession ? 'signed-in' : 'signed-out');
      setProfile(null);
    });
    void supabase.auth.getSession().then(({ data, error }) => {
      if (!alive) return;
      setSession(data.session);
      setAuthState(error ? 'signed-out' : data.session ? 'signed-in' : 'signed-out');
    });
    return () => { alive = false; listener.subscription.unsubscribe(); };
  }, []);

  useEffect(() => {
    if (!session || !supabase) {
      setProfile(null);
      setProfileState('loading');
      return;
    }
    let alive = true;
    setProfileState('loading');
    void supabase.from('profiles').select('id,display_name,role,active,employee_identifier').eq('id', session.user.id).maybeSingle()
      .then(({ data, error }) => {
        if (!alive) return;
        if (error) {
          setProfileError(error.message);
          setProfileState('error');
        } else if (!data) {
          setProfileState('missing');
        } else if (!data.active) {
          setProfileError('Akun ini sudah dinonaktifkan. Hubungi admin organisasi.');
          setProfileState('error');
        } else {
          setProfile(data as Profile);
          setProfileState('ready');
        }
      });
    return () => { alive = false; };
  }, [session]);

  if (authState === 'unconfigured') {
    return <main className="setup-page"><section className="setup-card"><div className="logo-mark"><Activity size={22} /></div><p className="eyebrow">MARKET INTEL · DEVELOPMENT</p><h1>Hubungkan Supabase development</h1><p className="muted">Dashboard tidak menampilkan angka contoh. Atur URL dan publishable key di <code>.env.local</code>, lalu jalankan migration pada Supabase lokal sebelum masuk.</p><div className="setup-steps"><span>1</span><p>Salin <code>.env.example</code> ke <code>.env.local</code>.</p><span>2</span><p>Isi URL dan publishable key dari project development.</p><span>3</span><p>Jalankan migration serta seed data sintetis, lalu muat ulang.</p></div><p className="login-footnote">Jangan masukkan service-role key ke browser.</p></section></main>;
  }
  if (authState === 'loading') return <main className="loading-page"><div className="spinner" />Memeriksa sesi Supabase…</main>;
  if (authState === 'signed-out' || !session) return <LoginScreen onSignedIn={(nextSession) => { setSession(nextSession); setAuthState('signed-in'); }} />;
  if (profileState === 'loading') return <main className="loading-page"><div className="spinner" />Memeriksa role dan cakupan akses…</main>;
  if (profileState === 'missing') return <main className="setup-page"><section className="setup-card"><div className="logo-mark"><Users size={22} /></div><h1>Profil belum disiapkan</h1><p className="muted">Akun Auth ini belum memiliki profil aplikasi. Minta admin menambahkan role dan cakupan akses.</p><button className="button button-secondary" onClick={() => void supabase?.auth.signOut()}>Keluar</button></section></main>;
  if (profileState === 'error') return <main className="setup-page"><section className="setup-card"><div className="logo-mark"><AlertTriangle size={22} /></div><h1>Akses tidak tersedia</h1><p className="muted">{profileError}</p><button className="button button-secondary" onClick={() => void supabase?.auth.signOut()}>Keluar</button></section></main>;
  if (!profile) return null;
  if (profile.role !== 'admin') return <main className="setup-page"><section className="setup-card"><div className="logo-mark"><ShieldCheck size={22} /></div><p className="eyebrow">ROLE · {profile.role.toUpperCase()}</p><h1>Modul admin tidak diizinkan</h1><p className="muted">Akun ini telah dikenali, tetapi belum diarahkan ke workspace sesuai role. Perizinan database tetap berlaku di luar tampilan ini.</p><button className="button button-secondary" onClick={() => void supabase?.auth.signOut()}>Keluar</button></section></main>;

  return <AdminApp profile={profile} onSignOut={() => { void supabase?.auth.signOut(); setSession(null); setProfile(null); setAuthState('signed-out'); }} />;
}
