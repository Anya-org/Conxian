import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import { markdownLinks, validateDocumentation } from "../scripts/validate-docs.js";

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "conxian-docs-validator-"));
  fs.mkdirSync(path.join(root, "docs", "knowledge"), { recursive: true });
  fs.mkdirSync(path.join(root, "contracts", "example"), { recursive: true });
  fs.writeFileSync(path.join(root, "docs", "knowledge", "valid.json"), "{}\n");
  fs.writeFileSync(path.join(root, "contracts", "example", "README.md"), "# Example\n");
  return root;
}

test("valid relative links pass", (context) => {
  const root = fixture();
  context.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.writeFileSync(path.join(root, "target.md"), "# Target\n");
  fs.writeFileSync(path.join(root, "README.md"), "[target](target.md)\n");

  assert.deepEqual(validateDocumentation(root).errors, []);
});

test("missing relative targets fail", (context) => {
  const root = fixture();
  context.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.writeFileSync(path.join(root, "README.md"), "[missing](missing.md)\n");

  assert.match(validateDocumentation(root).errors.join("\n"), /missing local target missing\.md/);
});

test("plain prose and escaped delimiters are not treated as links", () => {
  const markdown = String.raw`Plain prose can contain ](missing.md) without a label.
\[escaped opener](missing.md)
[escaped closer\](missing.md)
[label]\(missing.md)
`;

  assert.deepEqual(markdownLinks(markdown), { links: [], errors: [] });
});

test("nested labels and image labels are scanned", () => {
  assert.deepEqual(markdownLinks("[outer [inner]](nested.md)\n![alt](image.png)\n").links, [
    { line: 1, destination: "nested.md" },
    { line: 2, destination: "image.png" },
  ]);
});

test("links in inline code, comments, and fences are ignored", (context) => {
  const root = fixture();
  context.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.writeFileSync(path.join(root, "target.md"), "# Target\n");
  fs.writeFileSync(
    path.join(root, "README.md"),
    [
      "# Example",
      "",
      "`[inline](inline-missing.md)` and [target](target.md)",
      "`[inline-reference]: inline-reference-missing.md`",
      "<!-- [comment](comment-missing.md) -->",
      "<!-- [comment-reference]: comment-reference-missing.md -->",
      "```markdown",
      "[illustrative](fence-missing.md)",
      "[reference]: fence-reference-missing.md",
      "```",
      "",
    ].join("\n"),
  );

  assert.deepEqual(validateDocumentation(root).errors, []);
});

test("reference-style link and image definitions validate local targets", (context) => {
  const root = fixture();
  context.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.writeFileSync(path.join(root, "target.md"), "# Target\n");
  fs.writeFileSync(path.join(root, "image.png"), "not-an-image\n");
  fs.writeFileSync(
    path.join(root, "README.md"),
    [
      "[document][doc]",
      "![diagram][diagram]",
      "[external][site]",
      "",
      "[doc]: target.md",
      "[diagram]: image.png \"Diagram title\"",
      "[site]: https://example.com/docs",
      "",
    ].join("\n"),
  );

  assert.deepEqual(validateDocumentation(root).errors, []);
});

test("missing local targets in reference definitions fail even when unused", (context) => {
  const root = fixture();
  context.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.writeFileSync(path.join(root, "README.md"), "[unused]: missing-reference.md\n");

  assert.match(
    validateDocumentation(root).errors.join("\n"),
    /missing local target missing-reference\.md/,
  );
});

test("existing symlink targets cannot escape the repository", (context) => {
  const root = fixture();
  const outside = fs.mkdtempSync(path.join(os.tmpdir(), "conxian-docs-outside-"));
  context.after(() => {
    fs.rmSync(root, { recursive: true, force: true });
    fs.rmSync(outside, { recursive: true, force: true });
  });
  fs.writeFileSync(path.join(outside, "secret.md"), "# Outside\n");
  try {
    fs.symlinkSync(path.join(outside, "secret.md"), path.join(root, "outside-link.md"));
  } catch (error) {
    if (["EPERM", "EACCES", "ENOTSUP"].includes(error.code)) {
      context.skip(`symlinks are unavailable on this OS: ${error.code}`);
      return;
    }
    throw error;
  }
  fs.writeFileSync(path.join(root, "README.md"), "[outside](outside-link.md)\n");

  assert.match(
    validateDocumentation(root).errors.join("\n"),
    /local target resolves outside repository: outside-link\.md/,
  );
});

test("malformed knowledge JSON fails", (context) => {
  const root = fixture();
  context.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.writeFileSync(path.join(root, "README.md"), "# Fixture\n");
  fs.writeFileSync(path.join(root, "docs", "knowledge", "invalid.json"), "{ nope\n");

  assert.match(validateDocumentation(root).errors.join("\n"), /malformed JSON/);
});
