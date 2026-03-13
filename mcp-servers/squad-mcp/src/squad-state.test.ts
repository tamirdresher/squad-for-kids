/**
 * Tests for squad-state.ts — Team member parsing
 */

import { describe, it } from "node:test";
import { strict as assert } from "node:assert";
import { SquadState } from "./squad-state.js";
import { writeFile, rm, mkdir } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";

describe("SquadState", () => {
  describe("getTeamMembers", () => {
    it("should parse valid team.md with agent members", async () => {
      const testDir = join(tmpdir(), `squad-test-${Date.now()}`);
      await mkdir(testDir, { recursive: true });

      const teamMd = `# Squad Team

## Members

| Name | Role | Charter | Status |
|------|------|---------|--------|
| @picard | Lead | Architecture decisions | 🟢 Active |
| @data | Code Expert | C#, Go, .NET | 🟢 Active |
| 👤 @human | Human | Owner | 🟢 Active |
| @copilot | Bot | Automation | 🟢 Active |
`;

      await writeFile(join(testDir, "team.md"), teamMd);

      const state = new SquadState({ squadRoot: testDir, github: { token: "", owner: "", repo: "" } });
      const members = await state.getTeamMembers();

      assert.equal(members.length, 2);
      assert.equal(members[0].name, "@picard");
      assert.equal(members[0].role, "Lead");
      assert.equal(members[1].name, "@data");
      assert.equal(members[1].role, "Code Expert");

      await rm(testDir, { recursive: true });
    });

    it("should skip header row and human members", async () => {
      const testDir = join(tmpdir(), `squad-test-${Date.now()}`);
      await mkdir(testDir, { recursive: true });

      const teamMd = `## Members

| Name | Role | Charter | Status |
|------|------|---------|--------|
| 👤 @alice | Human | Product Owner | 🟢 Active |
| @worf | Security Expert | Azure, Security | 🟢 Active |
`;

      await writeFile(join(testDir, "team.md"), teamMd);

      const state = new SquadState({ squadRoot: testDir, github: { token: "", owner: "", repo: "" } });
      const members = await state.getTeamMembers();

      assert.equal(members.length, 1);
      assert.equal(members[0].name, "@worf");

      await rm(testDir, { recursive: true });
    });

    it("should throw descriptive error if team.md is missing", async () => {
      const testDir = join(tmpdir(), `squad-test-${Date.now()}`);
      await mkdir(testDir, { recursive: true });

      const state = new SquadState({ squadRoot: testDir, github: { token: "", owner: "", repo: "" } });

      await assert.rejects(
        () => state.getTeamMembers(),
        /Failed to read team\.md/
      );

      await rm(testDir, { recursive: true });
    });

    it("should handle empty members section", async () => {
      const testDir = join(tmpdir(), `squad-test-${Date.now()}`);
      await mkdir(testDir, { recursive: true });

      const teamMd = `## Members

| Name | Role | Charter | Status |
|------|------|---------|--------|

## Other Section
`;

      await writeFile(join(testDir, "team.md"), teamMd);

      const state = new SquadState({ squadRoot: testDir, github: { token: "", owner: "", repo: "" } });
      const members = await state.getTeamMembers();

      assert.equal(members.length, 0);

      await rm(testDir, { recursive: true });
    });
  });
});
