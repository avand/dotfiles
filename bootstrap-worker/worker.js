// Serves bootstrap.sh at https://bootstrap.avand.dev.
//
// It proxies the file straight from GitHub rather than embedding a copy, so
// editing bootstrap.sh in the repo is enough — no redeploy needed. The short
// cache keeps a rewrite from taking effect an hour later.

const SOURCE =
  "https://raw.githubusercontent.com/avand/dotfiles/master/bootstrap.sh";

export default {
  async fetch() {
    const upstream = await fetch(SOURCE, { cf: { cacheTtl: 60 } });

    // Fail loudly as a script: whatever we return may get piped into bash, so a
    // stray HTML error page would be worse than an obvious `exit 1`.
    if (!upstream.ok) {
      return new Response(
        `#!/usr/bin/env bash\necho "could not fetch bootstrap.sh (HTTP ${upstream.status})" >&2\nexit 1\n`,
        { status: 502, headers: { "content-type": "text/plain; charset=utf-8" } },
      );
    }

    return new Response(upstream.body, {
      headers: {
        "content-type": "text/plain; charset=utf-8",
        "cache-control": "public, max-age=60",
      },
    });
  },
};
