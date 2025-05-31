# GitHub Copilot Custom Instructions for Drasi

## Purpose
Guide Copilot to generate, design, and maintain Drasi reactions, sources, and continuous queries using best practices from the official Drasi documentation and repositories.

## Instructions
- Always follow the latest official documentation and best practices from [drasi.io](https://drasi.io/) and the [Drasi GitHub organization](https://github.com/orgs/drasi-project/repositories).
- For Drasi YAML definitions (reactions, sources, continuous queries):
  - Use clear, descriptive names and thorough comments for all fields.
  - Structure YAML according to Drasi templates and examples.
  - Write Cypher queries that follow official syntax, are efficient, and avoid unnecessary complexity.
  - Always use parameterized Cypher queries to prevent injection and security issues.
  - Validate and sanitize all user or external inputs.
  - Document the purpose, expected behavior, and triggers for each reaction, source, or query.
  - Prefer modular, reusable, and composable patterns for event-driven workflows.
  - Apply the principle of least privilege for all access and role assignments.
  - Test queries and logic with representative data, using Drasi-provided test harnesses or examples where possible.
- Reference and adapt the latest Drasi YAML templates and Cypher query examples from the official repositories.
- When in doubt, consult the [Drasi documentation](https://drasi.io/), [Drasi GitHub repositories](https://github.com/orgs/drasi-project/repositories), and [Cypher Query Language reference](https://neo4j.com/docs/cypher-manual/current/).

---

*These instructions help ensure high-quality, maintainable, and secure Drasi YAML configurations and Cypher queries in this repository, following the latest community and project standards.*
