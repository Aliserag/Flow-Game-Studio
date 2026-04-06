// generate-contract-docs.ts
// Parses Cadence contract source files and generates Markdown API docs.
// Extracts: contract name, access(all) declarations, events, storage paths, entitlements.

import * as fs from "fs";
import * as path from "path";
import { glob } from "glob";

interface ContractDoc {
  name: string;
  filePath: string;
  entitlements: string[];
  storagePaths: string[];
  events: string[];
  publicFunctions: string[];
  resources: string[];
}

function parseContract(source: string, filePath: string): ContractDoc {
  const name = (source.match(/access\(all\)\s+contract\s+(\w+)/) ?? [])[1] ?? path.basename(filePath, ".cdc");

  const entitlements = [...source.matchAll(/access\(all\)\s+entitlement\s+(\w+)/g)].map((m) => m[1]);

  const storagePaths = [...source.matchAll(/StoragePath\s*=\s*(\/storage\/\w+)/g)].map((m) => m[1]);

  const events = [...source.matchAll(/access\(all\)\s+event\s+(\w+)\(([^)]*)\)/g)].map(
    (m) => `${m[1]}(${m[2].replace(/\s+/g, " ").trim()})`
  );

  const publicFunctions = [
    ...source.matchAll(/access\(all\)\s+fun\s+(\w+)\s*\(([^)]*)\)(?:\s*:\s*([^\{]+))?/g),
  ].map((m) => `${m[1]}(${m[2].replace(/\s+/g, " ").trim()})${m[3] ? ": " + m[3].trim() : ""}`);

  const resources = [...source.matchAll(/access\(all\)\s+resource\s+(\w+)/g)].map((m) => m[1]);

  return { name, filePath, entitlements, storagePaths, events, publicFunctions, resources };
}

function generateMarkdown(doc: ContractDoc): string {
  const lines: string[] = [
    `# ${doc.name}`,
    ``,
    `**Source:** \`${doc.filePath}\``,
    ``,
  ];

  if (doc.entitlements.length > 0) {
    lines.push(`## Entitlements`, ``);
    doc.entitlements.forEach((e) => lines.push(`- \`${e}\``));
    lines.push(``);
  }

  if (doc.resources.length > 0) {
    lines.push(`## Resources`, ``);
    doc.resources.forEach((r) => lines.push(`- \`${r}\``));
    lines.push(``);
  }

  if (doc.storagePaths.length > 0) {
    lines.push(`## Storage Paths`, ``);
    doc.storagePaths.forEach((p) => lines.push(`- \`${p}\``));
    lines.push(``);
  }

  if (doc.events.length > 0) {
    lines.push(`## Events`, ``);
    doc.events.forEach((e) => lines.push(`- \`${e}\``));
    lines.push(``);
  }

  if (doc.publicFunctions.length > 0) {
    lines.push(`## Public Functions`, ``);
    doc.publicFunctions.forEach((f) => lines.push(`- \`${f}\``));
    lines.push(``);
  }

  return lines.join("\n");
}

async function main(): Promise<void> {
  const contractFiles = await glob("cadence/contracts/**/*.cdc");
  const outputDir = "docs/flow/contracts";
  fs.mkdirSync(outputDir, { recursive: true });

  const index: string[] = ["# Contract API Reference", "", "Auto-generated from source.", ""];

  for (const filePath of contractFiles.sort()) {
    const source = fs.readFileSync(filePath, "utf8");
    const doc = parseContract(source, filePath);
    const markdown = generateMarkdown(doc);
    const outPath = path.join(outputDir, `${doc.name}.md`);
    fs.writeFileSync(outPath, markdown);
    index.push(`- [${doc.name}](contracts/${doc.name}.md)`);
    console.log(`Generated: ${outPath}`);
  }

  fs.writeFileSync(path.join("docs/flow", "contract-index.md"), index.join("\n"));
  console.log(`Index written: docs/flow/contract-index.md`);
}

main();
