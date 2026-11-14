import process from "node:process";

const apiOrigin = (process.env.TESTAGRAM_API_URL || "").replace(/\/+$/, "");
const oidcToken = process.env.GITHUB_OIDC_TOKEN || "";
const batchSize = 100;
const probeTimeoutMs = 8000;
const concurrency = 12;

if (!apiOrigin || !oidcToken) {
  throw new Error("TESTAGRAM_API_URL and GITHUB_OIDC_TOKEN are required");
}

function safePublicStreamUrl(raw) {
  let url;
  try {
    url = new URL(String(raw || ""));
  } catch {
    return null;
  }
  if (!["http:", "https:"].includes(url.protocol) || !url.hostname ||
      url.username || url.password) return null;

  const host = url.hostname.toLowerCase().replace(/^\[|\]$/g, "");
  if (host === "localhost" || host.endsWith(".localhost") ||
      host.endsWith(".local") || host === "::1" || host.startsWith("fc") ||
      host.startsWith("fd") || host.startsWith("fe80:")) return null;

  const octets = host.split(".").map(Number);
  if (octets.length === 4 && octets.every(n => Number.isInteger(n) && n >= 0 && n <= 255)) {
    const [a, b] = octets;
    if (a === 0 || a === 10 || a === 127 || a >= 224 ||
        (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) ||
        (a === 192 && b === 168)) return null;
  }
  return url;
}

async function probe(rawUrl) {
  const started = Date.now();
  let url = safePublicStreamUrl(rawUrl);
  if (!url) return { is_online: false, latency_ms: 0, check_error: "invalid or non-public stream URL" };

  try {
    for (let redirects = 0; redirects <= 4; redirects++) {
      const response = await fetch(url, {
        method: "GET",
        headers: { range: "bytes=0-0", accept: "*/*" },
        redirect: "manual",
        signal: AbortSignal.timeout(probeTimeoutMs),
      });
      if ([301, 302, 303, 307, 308].includes(response.status)) {
        const location = response.headers.get("location");
        await response.body?.cancel();
        if (!location || redirects === 4) throw new Error("too many or invalid redirects");
        url = safePublicStreamUrl(new URL(location, url).toString());
        if (!url) throw new Error("redirect target is not a public HTTP(S) URL");
        continue;
      }
      const online = response.status >= 200 && response.status < 300;
      await response.body?.cancel();
      return {
        is_online: online,
        latency_ms: Math.min(30000, Date.now() - started),
        check_error: online ? "" : `HTTP ${response.status}`,
      };
    }
    throw new Error("redirect limit exceeded");
  } catch (error) {
    return {
      is_online: false,
      latency_ms: Math.min(30000, Date.now() - started),
      check_error: String(error?.message || error).slice(0, 500),
    };
  }
}

async function fetchCatalogue() {
  const response = await fetch(`${apiOrigin}/internal/tv/catalog`, {
    headers: {
      accept: "application/json",
      "x-github-oidc-token": oidcToken,
    },
    signal: AbortSignal.timeout(30000),
  });
  if (!response.ok) throw new Error(`TV catalogue request failed: HTTP ${response.status}`);
  const payload = await response.json();
  const channels = Array.isArray(payload?.channels) ? payload.channels :
    Array.isArray(payload?.data?.channels) ? payload.data.channels : null;
  if (!channels) throw new Error("Backend TV catalogue response has no channels array");
  if (channels.length > 20000) throw new Error("TV catalogue exceeds the 20,000-channel monitor limit");
  return channels;
}

async function mapConcurrent(items, limit, mapper) {
  const output = new Array(items.length);
  let next = 0;
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (true) {
      const index = next++;
      if (index >= items.length) return;
      output[index] = await mapper(items[index], index);
    }
  }));
  return output;
}

const channels = await fetchCatalogue();
if (channels.length === 0) {
  throw new Error("Backend TV catalogue is empty; refusing to report a successful health-monitor run without any provisioned channels. Provision verified channels before enabling production monitoring.");
}

let checked = 0;
for (let offset = 0; offset < channels.length; offset += batchSize) {
  const sourceBatch = channels.slice(offset, offset + batchSize);
  const records = await mapConcurrent(sourceBatch, concurrency, async (channel) => {
    const id = String(channel?.id ?? channel?.channel_id ?? "").trim();
    const url = String(channel?.url ?? channel?.stream_url ?? channel?.playback_url ?? "").trim();
    if (!/^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(id)) {
      throw new Error(`Catalogue record at index ${offset} has an invalid channel ID`);
    }
    if (!safePublicStreamUrl(url)) throw new Error(`Catalogue channel ${id} has an invalid or non-public HTTP(S) URL`);
    const result = await probe(url);
    return {
      channel_id: id,
      url,
      is_online: result.is_online,
      latency_ms: result.latency_ms,
      check_error: result.check_error,
      source: String(channel?.source ?? "").slice(0, 128),
      country: String(channel?.country ?? "").slice(0, 128),
      group_name: String(channel?.group_name ?? channel?.category ?? "").slice(0, 256),
      priority: Number.isInteger(channel?.priority) ? Math.max(0, Math.min(100000, channel.priority)) : 0,
    };
  });

  const response = await fetch(`${apiOrigin}/internal/tv/health`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-github-oidc-token": oidcToken,
    },
    body: JSON.stringify({ channels: records }),
    signal: AbortSignal.timeout(30000),
  });
  if (!response.ok) {
    const detail = (await response.text()).slice(0, 1000);
    throw new Error(`TV health batch ${Math.floor(offset / batchSize) + 1} failed: HTTP ${response.status} ${detail}`);
  }
  const result = await response.json();
  checked += Number(result.checked || 0);
  console.log(JSON.stringify({
    batch: Math.floor(offset / batchSize) + 1,
    submitted: records.length,
    persisted: result.persisted ?? result.checked ?? 0,
  }));
}
console.log(`Total TV channels checked: ${checked}`);
