/**
 * Tests for config.ts — Configuration loading and validation
 */

import { describe, it, beforeEach, afterEach } from "node:test";
import { strict as assert } from "node:assert";
import { loadConfig } from "./config.js";

describe("loadConfig", () => {
  let originalEnv: NodeJS.ProcessEnv;

  beforeEach(() => {
    originalEnv = { ...process.env };
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  it("should load config from environment variables", async () => {
    process.env.GITHUB_TOKEN = "test-token";
    process.env.GITHUB_OWNER = "test-owner";
    process.env.GITHUB_REPO = "test-repo";
    process.env.SQUAD_ROOT = "/test/squad";

    const config = await loadConfig();

    assert.equal(config.github.token, "test-token");
    assert.equal(config.github.owner, "test-owner");
    assert.equal(config.github.repo, "test-repo");
    assert.equal(config.squadRoot, "/test/squad");
  });

  it("should auto-detect squadRoot if not provided", async () => {
    process.env.GITHUB_TOKEN = "test-token";
    process.env.GITHUB_OWNER = "test-owner";
    process.env.GITHUB_REPO = "test-repo";
    delete process.env.SQUAD_ROOT;

    const config = await loadConfig();

    assert.ok(config.squadRoot?.endsWith(".squad"));
  });

  it("should throw error when no config is available", async () => {
    delete process.env.GITHUB_TOKEN;
    delete process.env.GITHUB_OWNER;
    delete process.env.GITHUB_REPO;
    delete process.env.SQUAD_ROOT;

    await assert.rejects(
      () => loadConfig(),
      /Configuration not found/
    );
  });

  it("should handle partial environment variables", async () => {
    process.env.GITHUB_TOKEN = "test-token";
    delete process.env.GITHUB_OWNER;
    delete process.env.GITHUB_REPO;

    await assert.rejects(
      () => loadConfig(),
      /Configuration not found/
    );
  });
});
