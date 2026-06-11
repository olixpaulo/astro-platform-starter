"""Painel administrativo web — SPA leve servida pela própria API.

Consome os endpoints /api/v1/admin/* com o JWT de um utilizador admin.
"""

ADMIN_PANEL_HTML = r"""<!DOCTYPE html>
<html lang="pt">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>GlobalTranslate — Admin</title>
<style>
  :root {
    --primary: #1565D8; --primary-dark: #0D47A1; --bg: #F5F7FA;
    --surface: #FFFFFF; --text: #1A1F36; --muted: #6B7280; --danger: #DC2626;
  }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #0F172A; --surface: #1E293B; --text: #F1F5F9; --muted: #94A3B8; }
  }
  * { box-sizing: border-box; margin: 0; }
  body { font-family: system-ui, -apple-system, sans-serif; background: var(--bg); color: var(--text); }
  header { background: var(--primary); color: #fff; padding: 14px 24px; display: flex; justify-content: space-between; align-items: center; }
  header h1 { font-size: 18px; font-weight: 600; }
  nav button { background: none; border: none; color: #fff; padding: 8px 14px; cursor: pointer; border-radius: 8px; font-size: 14px; }
  nav button.active, nav button:hover { background: var(--primary-dark); }
  main { max-width: 1100px; margin: 24px auto; padding: 0 16px; }
  .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 16px; margin-bottom: 24px; }
  .card { background: var(--surface); border-radius: 12px; padding: 18px; box-shadow: 0 1px 3px rgba(0,0,0,.08); }
  .card .value { font-size: 28px; font-weight: 700; color: var(--primary); }
  .card .label { color: var(--muted); font-size: 13px; margin-top: 4px; }
  table { width: 100%; border-collapse: collapse; background: var(--surface); border-radius: 12px; overflow: hidden; }
  th, td { padding: 10px 14px; text-align: left; font-size: 14px; border-bottom: 1px solid rgba(128,128,128,.15); }
  th { color: var(--muted); font-weight: 600; font-size: 12px; text-transform: uppercase; }
  input, select { padding: 9px 12px; border: 1px solid rgba(128,128,128,.3); border-radius: 8px; background: var(--surface); color: var(--text); font-size: 14px; }
  button.action { background: var(--primary); color: #fff; border: none; padding: 9px 16px; border-radius: 8px; cursor: pointer; font-size: 14px; }
  button.danger { background: var(--danger); }
  .toolbar { display: flex; gap: 10px; margin-bottom: 14px; flex-wrap: wrap; }
  #login { max-width: 360px; margin: 80px auto; display: flex; flex-direction: column; gap: 12px; }
  .badge { padding: 2px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; }
  .badge.ok { background: #DCFCE7; color: #166534; } .badge.off { background: #FEE2E2; color: #991B1B; }
  .hidden { display: none; }
</style>
</head>
<body>
<header>
  <h1>🌍 GlobalTranslate Admin</h1>
  <nav id="nav" class="hidden">
    <button data-view="stats" class="active">Estatísticas</button>
    <button data-view="users">Utilizadores</button>
    <button data-view="plans">Planos</button>
    <button data-view="logs">Logs</button>
    <button onclick="logout()">Sair</button>
  </nav>
</header>
<main>
  <div id="login" class="card">
    <h2>Iniciar sessão</h2>
    <input id="email" type="email" placeholder="Email de administrador" autocomplete="username">
    <input id="password" type="password" placeholder="Senha" autocomplete="current-password">
    <button class="action" onclick="login()">Entrar</button>
    <p id="loginError" style="color:var(--danger);font-size:13px"></p>
  </div>
  <div id="app" class="hidden">
    <section id="view-stats"></section>
    <section id="view-users" class="hidden"></section>
    <section id="view-plans" class="hidden"></section>
    <section id="view-logs" class="hidden"></section>
  </div>
</main>
<script>
const API = '/api/v1';
let token = sessionStorage.getItem('gt_admin_token');

async function api(path, options = {}) {
  const res = await fetch(API + path, {
    ...options,
    headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token, ...(options.headers||{}) },
  });
  if (res.status === 401 || res.status === 403) { logout(); throw new Error('Sessão expirada'); }
  if (!res.ok) throw new Error((await res.json()).detail || res.statusText);
  return res.json();
}

async function login() {
  const email = document.getElementById('email').value;
  const password = document.getElementById('password').value;
  try {
    const res = await fetch(API + '/auth/login', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    if (!res.ok) throw new Error((await res.json()).detail || 'Falha no login');
    token = (await res.json()).access_token;
    sessionStorage.setItem('gt_admin_token', token);
    showApp();
  } catch (e) { document.getElementById('loginError').textContent = e.message; }
}

function logout() {
  sessionStorage.removeItem('gt_admin_token'); token = null;
  document.getElementById('app').classList.add('hidden');
  document.getElementById('nav').classList.add('hidden');
  document.getElementById('login').classList.remove('hidden');
}

function showApp() {
  document.getElementById('login').classList.add('hidden');
  document.getElementById('app').classList.remove('hidden');
  document.getElementById('nav').classList.remove('hidden');
  loadStats();
}

document.querySelectorAll('#nav button[data-view]').forEach(btn => btn.addEventListener('click', () => {
  document.querySelectorAll('#nav button').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  document.querySelectorAll('main section').forEach(s => s.classList.add('hidden'));
  document.getElementById('view-' + btn.dataset.view).classList.remove('hidden');
  ({ stats: loadStats, users: loadUsers, plans: loadPlans, logs: loadLogs })[btn.dataset.view]();
}));

const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

async function loadStats() {
  const s = await api('/admin/stats');
  document.getElementById('view-stats').innerHTML = `
    <div class="cards">
      <div class="card"><div class="value">${s.total_users}</div><div class="label">Utilizadores</div></div>
      <div class="card"><div class="value">${s.active_users_30d}</div><div class="label">Ativos (30 dias)</div></div>
      <div class="card"><div class="value">${s.premium_users}</div><div class="label">Premium</div></div>
      <div class="card"><div class="value">${s.translations_today}</div><div class="label">Traduções hoje</div></div>
      <div class="card"><div class="value">${s.translations_total}</div><div class="label">Traduções totais</div></div>
      <div class="card"><div class="value">€${(s.revenue_month_cents/100).toFixed(2)}</div><div class="label">Receita do mês</div></div>
    </div>
    <div class="card"><h3 style="margin-bottom:10px">Top pares de idiomas</h3>
      <table><tr><th>Origem</th><th>Destino</th><th>Traduções</th></tr>
      ${s.top_language_pairs.map(p => `<tr><td>${esc(p.source)}</td><td>${esc(p.target)}</td><td>${p.count}</td></tr>`).join('')}
      </table></div>`;
}

async function loadUsers(page = 1, search = '') {
  const data = await api(`/admin/users?page=${page}&search=${encodeURIComponent(search)}`);
  document.getElementById('view-users').innerHTML = `
    <div class="toolbar">
      <input id="userSearch" placeholder="Pesquisar email ou nome" value="${esc(search)}">
      <button class="action" onclick="loadUsers(1, document.getElementById('userSearch').value)">Pesquisar</button>
    </div>
    <table><tr><th>Email</th><th>Nome</th><th>Role</th><th>Estado</th><th>Ações</th></tr>
    ${data.items.map(u => `<tr>
      <td>${esc(u.email)}</td><td>${esc(u.full_name)}</td><td>${esc(u.role)}</td>
      <td><span class="badge ${u.is_active ? 'ok' : 'off'}">${u.is_active ? 'ativo' : 'inativo'}</span></td>
      <td><button class="action ${u.is_active ? 'danger' : ''}" onclick="toggleUser('${u.id}', ${!u.is_active})">
        ${u.is_active ? 'Desativar' : 'Ativar'}</button></td></tr>`).join('')}
    </table>
    <p style="margin-top:10px;color:var(--muted)">Total: ${data.total} · Página ${data.page}</p>`;
}

async function toggleUser(id, isActive) {
  await api('/admin/users/' + id, { method: 'PATCH', body: JSON.stringify({ is_active: isActive }) });
  loadUsers();
}

async function loadPlans() {
  const plans = await api('/admin/plans');
  document.getElementById('view-plans').innerHTML = `
    <table><tr><th>Plano</th><th>Tier</th><th>Preço/mês</th><th>Limite diário</th><th>Doc. máx (MB)</th><th>Estado</th></tr>
    ${plans.map(p => `<tr><td>${esc(p.name)}</td><td>${esc(p.tier)}</td>
      <td>€${(p.price_monthly_cents/100).toFixed(2)}</td>
      <td>${p.daily_translation_limit ?? 'Ilimitado'}</td><td>${p.max_document_size_mb}</td>
      <td><span class="badge ${p.is_active !== false ? 'ok' : 'off'}">${p.is_active !== false ? 'ativo' : 'inativo'}</span></td></tr>`).join('')}
    </table>`;
}

async function loadLogs(page = 1) {
  const data = await api(`/admin/logs?page=${page}`);
  document.getElementById('view-logs').innerHTML = `
    <table><tr><th>Data</th><th>Ação</th><th>Utilizador</th><th>Detalhe</th><th>IP</th></tr>
    ${data.items.map(l => `<tr><td>${new Date(l.created_at).toLocaleString()}</td>
      <td>${esc(l.action)}</td><td>${esc(l.user_id || '—')}</td><td>${esc(l.detail || '')}</td><td>${esc(l.ip_address || '')}</td></tr>`).join('')}
    </table>
    <p style="margin-top:10px;color:var(--muted)">Total: ${data.total} · Página ${data.page}</p>`;
}

if (token) showApp();
</script>
</body>
</html>
"""
