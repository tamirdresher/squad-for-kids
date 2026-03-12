# AI Agent Contributor Agreement

## 1. Definitions

- **"AI Agent"**: Any automated system, including but not limited to GitHub Copilot, squad-assigned AI agents, and large language model-based tools, that generates, modifies, or reviews code, documentation, or other repository artifacts.
- **"Operator"**: The human squad member who initiates, directs, and supervises the AI Agent's actions.
- **"Repository Owner"**: The individual or organization that owns the repository to which contributions are made.
- **"Squad Lead"**: The designated human responsible for overall squad governance and accountability.
- **"Contribution"**: Any code, documentation, configuration, or other artifact produced by an AI Agent and submitted to the repository.

## 2. Nature of AI Agent Contributions

### 2.1 AI Agent as a Tool

An AI Agent is a tool operated by a human Operator, not an independent contributor. The AI Agent:

- Acts only at the direction of an Operator or an automated workflow approved by the Squad Lead
- Does not hold authorship rights or legal standing as a contributor
- Is identified in git history via `Co-authored-by` trailers for audit purposes only

### 2.2 Human Accountability

The Operator who initiates an AI Agent action is responsible for:

- Reviewing the AI Agent's output before it is merged
- Ensuring the output complies with repository standards and this agreement
- Classifying changes per the [AI Agent Change Control Policy](ai-agent-change-control.md)

## 3. Intellectual Property

### 3.1 Ownership

All Contributions produced by an AI Agent and submitted to this repository are the sole property of the Repository Owner. By directing an AI Agent to contribute to this repository, the Operator confirms that:

- The Contribution does not knowingly infringe any third-party intellectual property rights
- The Operator has the authority to submit the Contribution on behalf of the Repository Owner
- No license or ownership claim is asserted by or on behalf of the AI Agent or its provider

### 3.2 License

All Contributions are submitted under the same license that governs the repository. No additional or conflicting license terms apply to AI-generated content.

## 4. Liability and Responsibility

### 4.1 Squad Lead Accountability

The Squad Lead is ultimately accountable for all AI Agent Contributions. This includes:

- Ensuring the AI Agent Change Control Policy is followed
- Maintaining an up-to-date [Training Records](training-records-template.md) register
- Investigating and remediating any issues caused by AI-generated changes
- Reporting compliance incidents to the Repository Owner

### 4.2 Operator Responsibility

Each Operator is responsible for:

- Verifying that AI Agent output is correct, secure, and appropriate before approval
- Escalating uncertain or high-risk changes per the change control policy
- Not using AI Agents to circumvent review processes or branch protections

### 4.3 No Warranty

AI Agent output is provided as-is. Neither the AI Agent provider nor the AI Agent itself offers any warranty of fitness, correctness, or security. Human review is required for all Contributions.

## 5. Data Handling Requirements

### 5.1 Prohibited Inputs

Operators must not include the following in prompts, issues, or any input provided to an AI Agent:

- Secrets, tokens, passwords, or API keys
- Personally identifiable information (PII)
- Protected health information (PHI)
- Financial account numbers or payment card data
- Classified or export-controlled information

### 5.2 Output Safeguards

Before merging any AI-generated Contribution, the Operator must verify that the output does not contain:

- Hardcoded secrets or credentials
- PII or other sensitive data
- Copyrighted content reproduced without authorization
- Malicious code patterns

### 5.3 Data Residency

AI Agent interactions may be processed outside the repository's hosting region. Operators must ensure that no data subject to residency requirements is included in AI Agent inputs.

## 6. Compliance with Organizational Policies

### 6.1 Policy Hierarchy

This agreement operates within and is subordinate to:

1. Applicable laws and regulations
2. Organizational security and privacy policies
3. Repository-specific contributing guidelines (`CONTRIBUTING.md`)
4. The [AI Agent Change Control Policy](ai-agent-change-control.md)

### 6.2 Audit Support

All AI Agent activity must be auditable. This means:

- Contributions are traceable to a specific Operator and AI Agent via git history
- PR discussions and review comments are retained
- The Squad Lead can produce an activity report for any AI Agent upon request

### 6.3 Policy Updates

This agreement is reviewed quarterly alongside the change control policy. Changes require approval from the Repository Owner and the Squad Lead.

## 7. Acceptance

By directing an AI Agent to contribute to this repository, the Operator acknowledges and agrees to the terms of this agreement.

| Version | Date | Author | Change Summary |
|---------|------|--------|----------------|
| 1.0 | 2025-07-15 | Squad team | Initial agreement |
