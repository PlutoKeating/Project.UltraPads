// 入口：读环境变量、打开数据库、启动 HTTP，每天备份一次。
import { serve } from "@hono/node-server";
import { openDb } from "./db.ts";
import { createApp, VERSION } from "./app.ts";

const env = process.env;
const key = env.ULTRAPADS_DATA_KEY ?? "";
const adminKey = env.ULTRAPADS_ADMIN_KEY ?? "";
if (key.length < 32 || adminKey.length < 32) {
  console.error("ULTRAPADS_DATA_KEY 与 ULTRAPADS_ADMIN_KEY 都至少 32 个字符（start.sh 会自动生成）");
  process.exit(1);
}
if (key === adminKey) {
  console.error("ULTRAPADS_DATA_KEY 与 ULTRAPADS_ADMIN_KEY 不能相同");
  process.exit(1);
}
const dataDir = env.ULTRAPADS_DATA_DIR ?? "/data";
const port = Number(env.ULTRAPADS_DATA_PORT ?? 8080);
const host = env.ULTRAPADS_DATA_HOST ?? "0.0.0.0";

const db = openDb(dataDir);
const backup = () => {
  try {
    console.log("[backup]", db.backup(`${dataDir}/backups`));
  } catch (e) {
    console.error("[backup]", (e as Error).message);
  }
};
backup();
setInterval(backup, 6 * 3600_000).unref();

const server = serve(
  { fetch: createApp(db, key, adminKey).fetch, port, hostname: host },
  (a) => console.log(`[main] ultrapads-data ${VERSION} 在 ${host}:${a.port}`),
);
const stop = () => {
  server.close();
  db.close();
  process.exit(0);
};
process.on("SIGTERM", stop);
process.on("SIGINT", stop);
