# Per-Area Squad Configuration Examples

This directory contains reference implementations of the per-area `.squads/` configuration pattern for monorepo setups.

## Examples

### Platform Area (`platform-area/`)

A complete example showing infrastructure-focused area configuration:

- **Focus**: Kubernetes, Terraform, Azure infrastructure
- **Primary Owner**: B'Elanna
- **Key Features**:
  - Path-based routing (helm/, terraform/, services/)
  - File pattern routing (*.tf, Dockerfile, *_test.go)
  - Required capabilities (emu-gh)
  - Custom conventions (Helm validation, Terraform plan output)
  - Security gates (Worf reviews all infra changes)

**Files**:
- `.squads/config.json` - Full configuration
- `README.md` - Area overview

## Usage

### Quick Start

1. Copy an example directory structure to your area:
   ```bash
   cp -r examples/platform-area/ src/your-area/
   ```

2. Edit `.squads/config.json`:
   ```json
   {
     "version": 1,
     "area": {
       "name": "your-area",
       "path": "src/your-area",
       "owner": "YourAgent"
     }
   }
   ```

3. Validate:
   ```bash
   ./scripts/validate-squads-config.ps1
   ```

### Validation

All examples pass schema validation:

```bash
./scripts/validate-squads-config.ps1 -Path examples/platform-area/.squads/config.json
```

## Schema

See `.squad/schemas/squads-config.schema.json` for the complete JSON schema.

## Documentation

Full guide: `.squad/docs/per-area-squads.md`

## Adding Your Own Example

To contribute a new example:

1. Create directory: `examples/{area-name}/`
2. Add `.squads/config.json` with your configuration
3. Add `README.md` explaining the example
4. Validate: `./scripts/validate-squads-config.ps1`
5. Submit PR with label `squad:belanna`

Examples should demonstrate specific patterns:
- Different routing strategies
- Capability requirements
- Custom conventions
- Team overrides
- Complex path/pattern rules
