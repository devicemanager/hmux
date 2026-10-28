import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const scriptPath = fileURLToPath(new URL("./load-dev-env.sh", import.meta.url));

function sourceDevEnv({
  downloadedKeyID = "",
  downloadedPrivateKey = "",
  keyFileContents = "",
  localKeyID = "",
  providerFileContents = "",
  extraFileContents = "",
}) {
  const home = mkdtempSync(path.join(tmpdir(), "hmux-load-dev-env-"));
  const secrets = path.join(home, ".secrets");
  const envFile = path.join(secrets, "hmuxterm-dev.env");
  const providerFile = path.join(secrets, "hmux.env");
  const extraFile = path.join(secrets, "extra.env");
  const keyFile = path.join(
    secrets,
    "hmux-staging-relay-policy-2026-08.pem",
  );
  mkdirSync(secrets, { recursive: true });
  writeFileSync(
    envFile,
    [
      `HMUX_RELAY_POLICY_KEY_ID=${downloadedKeyID}`,
      `HMUX_RELAY_POLICY_PRIVATE_KEY_PEM=${downloadedPrivateKey}`,
      "",
    ].join("\n"),
    { mode: 0o600 },
  );
  writeFileSync(keyFile, keyFileContents, { mode: 0o600 });
  if (providerFileContents) {
    writeFileSync(providerFile, providerFileContents, { mode: 0o600 });
  }
  if (extraFileContents) {
    writeFileSync(extraFile, extraFileContents, { mode: 0o600 });
  }

  try {
    return execFileSync(
      "bash",
      [
        "-c",
        `source "$1"; printf '%s\\0%s\\0%s\\0%s\\0%s' "\${HMUX_RELAY_POLICY_KEY_ID-}" "\${HMUX_RELAY_POLICY_PRIVATE_KEY_PEM-}" "\${FREESTYLE_API_KEY-}" "\${FREESTYLE_SANDBOX_SNAPSHOT-}" "\${HMUX_VM_DEFAULT_PROVIDER-}"`,
        "bash",
        scriptPath,
      ],
      {
        encoding: "utf8",
        env: {
          ...process.env,
          HOME: home,
          HMUXTERM_ENV_FILE: envFile,
          HMUX_RELAY_POLICY_KEY_ID: "",
          HMUX_RELAY_POLICY_PRIVATE_KEY_PEM: "",
          HMUX_RELAY_POLICY_LOCAL_KEY_ID: localKeyID,
          HMUX_VM_DEFAULT_PROVIDER: "",
          HMUXTERM_EXTRA_ENV_FILE: extraFileContents ? extraFile : "",
        },
      },
    ).split("\0");
  } finally {
    rmSync(home, { recursive: true, force: true });
  }
}

test("blank downloaded relay secret falls back to the protected local key", () => {
  const privateKey = "-----BEGIN PRIVATE KEY-----\nlocal-dev\n-----END PRIVATE KEY-----\n";
  const [keyID, loadedPrivateKey] = sourceDevEnv({
    keyFileContents: privateKey,
  });

  assert.equal(keyID, "hmux-staging-relay-policy-2026-08");
  assert.equal(loadedPrivateKey, privateKey.trimEnd());
});

test("local fallback key replaces a stale downloaded key id", () => {
  const privateKey = "-----BEGIN PRIVATE KEY-----\nlocal-dev\n-----END PRIVATE KEY-----\n";
  const [keyID, loadedPrivateKey] = sourceDevEnv({
    downloadedKeyID: "hmux-staging-relay-policy-2026-07",
    keyFileContents: privateKey,
  });

  assert.equal(keyID, "hmux-staging-relay-policy-2026-08");
  assert.equal(loadedPrivateKey, privateKey.trimEnd());
});

test("complete downloaded key pair remains coupled", () => {
  const downloadedPrivateKey = "downloaded-private-key";
  const [keyID, loadedPrivateKey] = sourceDevEnv({
    downloadedKeyID: "downloaded-key-id",
    downloadedPrivateKey,
    keyFileContents: "local-private-key",
  });

  assert.equal(keyID, "downloaded-key-id");
  assert.equal(loadedPrivateKey, downloadedPrivateKey);
});

test("custom local fallback key id remains coupled to its private key", () => {
  const privateKey = "custom-local-private-key";
  const [keyID, loadedPrivateKey] = sourceDevEnv({
    downloadedKeyID: "stale-downloaded-key-id",
    keyFileContents: privateKey,
    localKeyID: "custom-local-key-id",
  });

  assert.equal(keyID, "custom-local-key-id");
  assert.equal(loadedPrivateKey, privateKey);
});

test("loads Freestyle credentials from the generic provider file", () => {
  const [, , apiKey, snapshot, provider] = sourceDevEnv({
    providerFileContents: "FREESTYLE_API_KEY=local-freestyle-key\nFREESTYLE_SANDBOX_SNAPSHOT=sh-local\n",
  });

  assert.equal(apiKey, "local-freestyle-key");
  assert.equal(snapshot, "sh-local");
  assert.equal(provider, "freestyle");
});

test("loads an explicitly selected Freestyle provider from the extra environment file", () => {
  const [, , apiKey, , provider] = sourceDevEnv({
    extraFileContents: "FREESTYLE_API_KEY=explicit-freestyle-key\nHMUX_VM_DEFAULT_PROVIDER=freestyle\n",
  });

  assert.equal(apiKey, "explicit-freestyle-key");
  assert.equal(provider, "freestyle");
});

function sourcedNetworkNamespace(env) {
  const home = mkdtempSync(path.join(tmpdir(), "hmux-load-dev-env-ns-"));
  const secrets = path.join(home, ".secrets");
  const envFile = path.join(secrets, "hmuxterm-dev.env");
  mkdirSync(secrets, { recursive: true });
  writeFileSync(envFile, "", { mode: 0o600 });
  const inherited = { ...process.env };
  delete inherited.HMUX_VM_NETWORK_NAMESPACE;
  delete inherited.DATABASE_URL;
  for (const key of ["HMUX_DEV_USE_EXTERNAL_DATABASE_URL", "HMUX_DEV_USE_PLANETSCALE", "HMUX_DB_PASSWORD", "HMUX_DB_PORT", "HMUX_DB_USER", "HMUX_DB_NAME", "HMUX_PORT", "PORT"]) {
    delete inherited[key];
  }
  try {
    return execFileSync(
      "bash",
      ["-c", `source "$1"; printf '%s:%s' "\${HMUX_VM_NETWORK_NAMESPACE+set}" "\${HMUX_VM_NETWORK_NAMESPACE-}"`, "bash", scriptPath],
      {
        encoding: "utf8",
        env: { ...inherited, HOME: home, HMUXTERM_ENV_FILE: envFile, HMUXTERM_EXTRA_ENV_FILE: "", ...env },
      },
    );
  } finally {
    rmSync(home, { recursive: true, force: true });
  }
}

test("each dev database gets its own Cloud network namespace", () => {
  // A dev-backend stack: Compose passes the stack's own database password
  // and URL; the shared secret file may carry another DATABASE_URL.
  const stack = (password) => ({
    HMUX_PORT: "3811",
    HMUX_DB_PASSWORD: password,
    HMUX_DEV_USE_EXTERNAL_DATABASE_URL: "1",
    DATABASE_URL: `postgres://hmux:${password}@postgres:5432/hmux`,
  });
  const stackA = sourcedNetworkNamespace(stack("stack-a-password"));
  const stackB = sourcedNetworkNamespace(stack("stack-b-password"));
  const local = sourcedNetworkNamespace({ HMUX_PORT: "3811" });
  for (const value of [stackA, stackB, local]) {
    assert.match(value, /^set:dev-[0-9a-f]{10}$/);
  }
  assert.notEqual(stackA, stackB);
  assert.notEqual(stackA, local);
  assert.equal(stackA, sourcedNetworkNamespace(stack("stack-a-password")));
  assert.notEqual(local, sourcedNetworkNamespace({ HMUX_PORT: "3812" }));
  assert.equal(stackA.includes("stack-a-password"), false);
});

test("an explicit Cloud network namespace, even empty, is kept", () => {
  assert.equal(sourcedNetworkNamespace({ HMUX_VM_NETWORK_NAMESPACE: "staging" }), "set:staging");
  assert.equal(sourcedNetworkNamespace({ HMUX_VM_NETWORK_NAMESPACE: "" }), "set:");
});
