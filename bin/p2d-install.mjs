#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { createInterface } from "node:readline/promises";
import { stdin as input, stdout as output } from "node:process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const supportedRuntimes = new Set(["codex", "claude", "copilot", "cursor", "service"]);
const args = new Map();
for (let index = 2; index < process.argv.length; index += 1) {
  const key = process.argv[index];
  if (!key.startsWith("--")) continue;
  const value = process.argv[index + 1];
  if (value && !value.startsWith("--")) {
    args.set(key.slice(2), value);
    index += 1;
  } else {
    args.set(key.slice(2), "true");
  }
}

const rl = createInterface({ input, output });
async function value(name, prompt, fallback = "") {
  const existing = args.get(name) || fallback;
  if (existing) return existing;
  return (await rl.question(`${prompt}: `)).trim();
}

console.log("\nPur2Divin Agentic Command Center Installer");
console.log("One machine. One product workspace. One governed squad.\n");

const product = await value("product", "Product workspace key", process.env.P2D_PRODUCT_KEY);
const productId = await value("product-id", "Product ID", process.env.P2D_PRODUCT_ID);
const squad = await value("squad", "Squad key", process.env.P2D_SQUAD_KEY);
const squadId = await value("squad-id", "Squad ID", process.env.P2D_SQUAD_ID);
const release = await value("release", "Release or wave key", process.env.P2D_RELEASE_KEY || "current");
const runtime = (await value("runtime", "Runtime (codex, claude, copilot, cursor, service)", process.env.P2D_RUNTIME)).toLowerCase();
const machine = args.get("machine") || process.env.P2D_MACHINE_KEY || "";
const actor = await value("actor", "Organization user ID", process.env.P2D_ACTOR);
const serviceUrl = await value(
  "url",
  "Command Center URL",
  process.env.P2D_COMMAND_CENTER_URL || "https://www.thep2d.com/p2d-command-center"
);
const token = await value(
  "token",
  "Enrollment token",
  process.env.P2D_ENROLLMENT_TOKEN || process.env.SERVICE_SHARED_SECRET
);
await rl.close();

if (!product || !productId || !squad || !squadId || !release || !actor || !token) {
  console.error("Product ID/key, squad ID/key, release, user ID, and enrollment token are required.");
  process.exit(1);
}
if (!supportedRuntimes.has(runtime)) {
  console.error(`Unsupported runtime: ${runtime}`);
  process.exit(1);
}

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const isWindows = process.platform === "win32";
const script = isWindows
  ? path.join(root, "windows", "install.ps1")
  : path.join(root, "mac-linux", "install.sh");
const command = isWindows ? "powershell.exe" : "bash";
const scriptArgs = isWindows
  ? [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      script,
      "-ProductKey",
      product,
      "-ProductId",
      productId,
      "-Squad",
      squad,
      "-SquadId",
      squadId,
      "-ReleaseKey",
      release,
      "-Runtime",
      runtime,
      "-Actor",
      actor,
      "-ServiceUrl",
      serviceUrl,
      "-Secret",
      token,
      ...(machine ? ["-HostKey", machine] : [])
    ]
  : [
      script,
      "--product",
      product,
      "--product-id",
      productId,
      "--squad",
      squad,
      "--squad-id",
      squadId,
      "--release",
      release,
      "--runtime",
      runtime,
      "--actor",
      actor,
      "--url",
      serviceUrl,
      ...(machine ? ["--host", machine] : [])
    ];

const result = spawnSync(command, scriptArgs, {
  stdio: "inherit",
  env: {
    ...process.env,
    P2D_ENROLLMENT_TOKEN: token,
    P2D_ACTOR: actor,
    P2D_PRODUCT_KEY: product,
    P2D_PRODUCT_ID: productId,
    P2D_SQUAD_KEY: squad,
    P2D_SQUAD_ID: squadId,
    P2D_RELEASE_KEY: release,
    P2D_RUNTIME: runtime,
    P2D_COMMAND_CENTER_URL: serviceUrl
  }
});

process.exit(result.status ?? 1);
