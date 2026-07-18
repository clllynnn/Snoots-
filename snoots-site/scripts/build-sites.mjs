import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const clientIndexPath = resolve(root, "dist/client/index.html");
const workerPath = resolve(root, "dist/server/index.js");
const hostingSourcePath = resolve(root, ".openai/hosting.json");
const hostingOutputPath = resolve(root, "dist/.openai/hosting.json");

const [indexHtml, hostingConfig] = await Promise.all([
  readFile(clientIndexPath, "utf8"),
  readFile(hostingSourcePath, "utf8"),
]);

const workerSource = `const indexHtml = ${JSON.stringify(indexHtml)};

function isPageRequest(request, url) {
  if (request.method !== "GET") return false;
  const lastSegment = url.pathname.split("/").pop() || "";
  return url.pathname === "/" || !lastSegment.includes(".");
}

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (isPageRequest(request, url)) {
      return new Response(indexHtml, {
        headers: {
          "content-type": "text/html; charset=utf-8",
          "cache-control": "public, max-age=0, must-revalidate",
        },
      });
    }

    return new Response("Not Found", { status: 404 });
  },
};
`;

await Promise.all([
  mkdir(dirname(workerPath), { recursive: true }),
  mkdir(dirname(hostingOutputPath), { recursive: true }),
]);

await Promise.all([
  writeFile(workerPath, workerSource),
  writeFile(hostingOutputPath, hostingConfig),
]);
