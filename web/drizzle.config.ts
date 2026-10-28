import { defineConfig } from "drizzle-kit";

function defaultDatabaseURL(): string {
  const rawPort = process.env.HMUX_PORT ?? process.env.PORT ?? "3777";
  const hmuxPort = /^\d+$/.test(rawPort) ? Number(rawPort) : 3777;
  const offset = Number(process.env.HMUX_DB_PORT_OFFSET ?? "10000");
  const dbPort = process.env.HMUX_DB_PORT ?? String(hmuxPort + offset);
  const user = process.env.HMUX_DB_USER ?? "hmux";
  const password = process.env.HMUX_DB_PASSWORD ?? "hmux";
  const database = process.env.HMUX_DB_NAME ?? "hmux";
  return `postgres://${user}:${password}@localhost:${dbPort}/${database}`;
}

export default defineConfig({
  schema: "./db/schema.ts",
  out: "./db/migrations",
  dialect: "postgresql",
  dbCredentials: {
    url: process.env.DIRECT_DATABASE_URL ?? process.env.DATABASE_URL ?? defaultDatabaseURL(),
  },
  strict: true,
  verbose: true,
});
