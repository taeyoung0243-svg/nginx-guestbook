const $ = (id) => document.getElementById(id);

function render(messages) {
  const list = $("list");
  list.replaceChildren();
  $("count").textContent = `(${messages.length})`;
  if (messages.length === 0) {
    const li = document.createElement("li");
    li.className = "empty";
    li.textContent = "아직 글이 없습니다. 첫 글을 남겨 보세요.";
    list.append(li);
    return;
  }
  for (const m of messages) {
    const li = document.createElement("li");
    const meta = document.createElement("div");
    meta.className = "meta";
    const who = document.createElement("span");
    who.className = "who";
    who.textContent = m.name;
    const when = document.createElement("time");
    when.textContent = new Date(m.created_at).toLocaleString("ko-KR");
    meta.append(who, when);
    const p = document.createElement("p");
    p.textContent = m.content; // textContent로 넣어 XSS 방지
    li.append(meta, p);
    list.append(li);
  }
}

async function load() {
  const res = await fetch("/api/messages");
  if (!res.ok) throw new Error(`목록을 불러오지 못했습니다 (${res.status})`);
  render(await res.json());
}

async function checkServer() {
  try {
    const res = await fetch("/api/health");
    const data = await res.json();
    $("server").textContent = `API 서버 정상 · host: ${data.hostname}`;
  } catch {
    $("server").textContent = "API 서버에 연결할 수 없습니다 (systemctl status guestbook-api 확인)";
  }
}

$("form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const btn = e.submitter;
  btn.disabled = true;
  $("error").textContent = "";
  try {
    const res = await fetch("/api/messages", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: $("name").value, content: $("content").value }),
    });
    if (!res.ok) throw new Error(`저장하지 못했습니다 (${res.status})`);
    $("content").value = "";
    await load();
  } catch (err) {
    $("error").textContent = err.message;
  } finally {
    btn.disabled = false;
  }
});

checkServer();
load().catch((err) => ($("error").textContent = err.message));
