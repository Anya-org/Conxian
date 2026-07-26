#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const MARKDOWN_EXTENSION = /\.md$/i;
const README_NAME = /^readme\.md$/i;
const EXTERNAL_SCHEME = /^[a-z][a-z0-9+.-]*:/i;

function walkFiles(directory, predicate) {
  if (!fs.existsSync(directory)) return [];

  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...walkFiles(entryPath, predicate));
    } else if (entry.isFile() && predicate(entryPath, entry.name)) {
      files.push(entryPath);
    }
  }
  return files;
}

export function documentationFiles(root) {
  const rootMarkdown = fs
    .readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isFile() && MARKDOWN_EXTENSION.test(entry.name))
    .map((entry) => path.join(root, entry.name));
  const docsMarkdown = walkFiles(
    path.join(root, "docs"),
    (entryPath) => MARKDOWN_EXTENSION.test(entryPath),
  );
  const contractReadmes = walkFiles(
    path.join(root, "contracts"),
    (entryPath, name) => README_NAME.test(name),
  );

  return [...new Set([...rootMarkdown, ...docsMarkdown, ...contractReadmes])].sort();
}

function stripIgnoredMarkdown(markdown) {
  const withoutComments = markdown.replace(/<!--[\s\S]*?-->/g, (comment) =>
    comment.replace(/[^\n]/g, ""),
  );
  const output = [];
  let fence = null;

  for (const line of withoutComments.split(/\r?\n/)) {
    const fenceMatch = line.match(/^ {0,3}(`{3,}|~{3,})/);
    if (fenceMatch) {
      const marker = fenceMatch[1][0];
      const length = fenceMatch[1].length;
      if (fence === null) {
        fence = { marker, length };
      } else if (fence.marker === marker && length >= fence.length) {
        fence = null;
      }
      output.push("");
      continue;
    }

    if (fence !== null) {
      output.push("");
      continue;
    }

    output.push(line.replace(/(`+)(.*?)\1/g, ""));
  }

  return output.join("\n");
}

function closingParenthesis(text, start) {
  let depth = 0;
  let escaped = false;
  for (let index = start; index < text.length; index += 1) {
    const character = text[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (character === "\\") {
      escaped = true;
      continue;
    }
    if (character === "(") depth += 1;
    if (character === ")") {
      if (depth === 0) return index;
      depth -= 1;
    }
  }
  return -1;
}

function isEscaped(text, index) {
  let backslashes = 0;
  for (let cursor = index - 1; cursor >= 0 && text[cursor] === "\\"; cursor -= 1) {
    backslashes += 1;
  }
  return backslashes % 2 === 1;
}

function parseDestination(rawDestination) {
  const value = rawDestination.trim();
  if (value === "") return "";

  if (value.startsWith("<")) {
    const end = value.indexOf(">");
    if (end === -1) throw new Error("unterminated angle-bracket link target");
    return value.slice(1, end);
  }

  const whitespace = value.search(/\s/);
  return (whitespace === -1 ? value : value.slice(0, whitespace)).replace(
    /\\([ ()])/g,
    "$1",
  );
}

export function markdownLinks(markdown) {
  const text = stripIgnoredMarkdown(markdown);
  const links = [];
  const errors = [];
  const lineStarts = [0];
  for (let index = 0; index < text.length; index += 1) {
    if (text[index] === "\n") lineStarts.push(index + 1);
  }

  const lineNumber = (offset) => {
    let low = 0;
    let high = lineStarts.length;
    while (low + 1 < high) {
      const middle = Math.floor((low + high) / 2);
      if (lineStarts[middle] <= offset) low = middle;
      else high = middle;
    }
    return low + 1;
  };

  const bracketStack = [];
  for (let cursor = 0; cursor < text.length; cursor += 1) {
    if (isEscaped(text, cursor)) continue;
    if (text[cursor] === "[") {
      bracketStack.push(cursor);
      continue;
    }
    if (text[cursor] !== "]") continue;

    const labelStart = bracketStack.pop();
    if (labelStart === undefined || text[cursor + 1] !== "(") continue;

    const targetStart = cursor + 2;
    const closing = closingParenthesis(text, targetStart);
    if (closing === -1) {
      errors.push({ line: lineNumber(cursor), message: "unterminated Markdown link" });
      break;
    }

    try {
      links.push({
        line: lineNumber(cursor),
        destination: parseDestination(text.slice(targetStart, closing)),
      });
    } catch (error) {
      errors.push({ line: lineNumber(cursor), message: error.message });
    }
    cursor = closing;
  }

  // Reference-style links and images are validated through their definitions.
  // Definitions in comments, code spans, and fenced examples were masked above.
  const referencePattern = /^ {0,3}\[((?:\\.|[^\]\\])+)\]:[ \t]*(\S.*)$/gm;
  for (const match of text.matchAll(referencePattern)) {
    try {
      links.push({
        line: lineNumber(match.index),
        destination: parseDestination(match[2]),
      });
    } catch (error) {
      errors.push({ line: lineNumber(match.index), message: error.message });
    }
  }

  return { links, errors };
}

function localTarget(destination) {
  if (
    destination === "" ||
    destination.startsWith("#") ||
    destination.startsWith("//") ||
    EXTERNAL_SCHEME.test(destination)
  ) {
    return null;
  }

  const withoutFragment = destination.split("#", 1)[0].split("?", 1)[0];
  if (withoutFragment === "") return null;
  try {
    return decodeURIComponent(withoutFragment);
  } catch {
    throw new Error(`invalid percent-encoding in link target: ${destination}`);
  }
}

export function validateDocumentation(root) {
  const errors = [];
  const markdownFiles = documentationFiles(root);
  const realRoot = fs.realpathSync(root);

  for (const markdownPath of markdownFiles) {
    const relativeMarkdownPath = path.relative(root, markdownPath) || path.basename(markdownPath);
    const { links, errors: syntaxErrors } = markdownLinks(
      fs.readFileSync(markdownPath, "utf8"),
    );
    for (const error of syntaxErrors) {
      errors.push(`${relativeMarkdownPath}:${error.line}: ${error.message}`);
    }

    for (const link of links) {
      let target;
      try {
        target = localTarget(link.destination);
      } catch (error) {
        errors.push(`${relativeMarkdownPath}:${link.line}: ${error.message}`);
        continue;
      }
      if (target === null) continue;

      const resolved = target.startsWith("/")
        ? path.join(root, target.slice(1))
        : path.resolve(path.dirname(markdownPath), target);
      const relativeTarget = path.relative(root, resolved);
      if (relativeTarget === ".." || relativeTarget.startsWith(`..${path.sep}`)) {
        errors.push(
          `${relativeMarkdownPath}:${link.line}: local target escapes repository: ${link.destination}`,
        );
        continue;
      }
      if (!fs.existsSync(resolved)) {
        errors.push(
          `${relativeMarkdownPath}:${link.line}: missing local target ${link.destination}`,
        );
        continue;
      }

      const realTarget = fs.realpathSync(resolved);
      const relativeRealTarget = path.relative(realRoot, realTarget);
      if (
        relativeRealTarget === ".." ||
        relativeRealTarget.startsWith(`..${path.sep}`)
      ) {
        errors.push(
          `${relativeMarkdownPath}:${link.line}: local target resolves outside repository: ${link.destination}`,
        );
      }
    }
  }

  const knowledgeDirectory = path.join(root, "docs", "knowledge");
  const knowledgeFiles = walkFiles(
    knowledgeDirectory,
    (entryPath) => entryPath.toLowerCase().endsWith(".json"),
  ).sort();
  for (const knowledgePath of knowledgeFiles) {
    try {
      JSON.parse(fs.readFileSync(knowledgePath, "utf8"));
    } catch (error) {
      errors.push(
        `${path.relative(root, knowledgePath)}: malformed JSON: ${error.message}`,
      );
    }
  }

  return {
    errors: errors.sort(),
    markdownCount: markdownFiles.length,
    knowledgeJsonCount: knowledgeFiles.length,
  };
}

function parseArguments(argv) {
  let root = process.cwd();
  for (let index = 0; index < argv.length; index += 1) {
    if (argv[index] === "--root") {
      if (!argv[index + 1]) throw new Error("--root requires a path");
      root = path.resolve(argv[index + 1]);
      index += 1;
    } else {
      throw new Error(`unknown argument: ${argv[index]}`);
    }
  }
  return root;
}

export function main(argv = process.argv.slice(2)) {
  let root;
  try {
    root = parseArguments(argv);
  } catch (error) {
    console.error(`Documentation validation failed: ${error.message}`);
    return 2;
  }

  const result = validateDocumentation(root);
  if (result.errors.length > 0) {
    console.error("Documentation validation failed:");
    for (const error of result.errors) console.error(`- ${error}`);
    return 1;
  }

  console.log(
    `Documentation validation passed (${result.markdownCount} Markdown files, ${result.knowledgeJsonCount} knowledge JSON files).`,
  );
  return 0;
}

const invokedPath = process.argv[1] ? path.resolve(process.argv[1]) : "";
if (invokedPath === fileURLToPath(import.meta.url)) {
  process.exitCode = main();
}
