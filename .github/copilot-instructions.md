# GitHub Copilot Custom Instructions for Drasi

## Purpose
Guide Copilot to generate, design, and maintain Drasi reactions, sources, and continuous queries using best practices from the official Drasi documentation and repositories.

## Core Documentation References
- **PRIMARY QUERY REFERENCE**: [https://drasi.io/reference/query-language/](https://drasi.io/reference/query-language/) - **ALWAYS consult this first for all query-related work**
- **Main Documentation**: [drasi.io](https://drasi.io/) - General Drasi concepts and getting started
- **GitHub Repositories**: [Drasi GitHub organization](https://github.com/orgs/drasi-project/repositories) - Latest examples and templates

## Instructions

### Query Language Specific Guidelines
When working with Drasi continuous queries:
- **MANDATORY**: Reference [https://drasi.io/reference/query-language/](https://drasi.io/reference/query-language/) for all query syntax, functions, and operators
- Use the Drasi Query Language (DQL) which extends Cypher with streaming-specific capabilities
- Follow DQL syntax rules as documented in the official query language reference
- Use Drasi-specific functions and operators as defined at [https://drasi.io/reference/query-language/](https://drasi.io/reference/query-language/)
- Validate query syntax against the Drasi Query Language specification
- Prefer Drasi's native query constructs over pure Cypher when available
- Always check the query language reference for the latest supported functions and syntax before writing queries

### General Drasi Development Guidelines
- Always follow the latest official documentation and best practices from [drasi.io](https://drasi.io/) and the [Drasi GitHub organization](https://github.com/orgs/drasi-project/repositories)
- For Drasi YAML definitions (reactions, sources, continuous queries):
  - Use clear, descriptive names and thorough comments for all fields
  - Structure YAML according to Drasi templates and examples
  - Write queries using Drasi Query Language (DQL) syntax from [https://drasi.io/reference/query-language/](https://drasi.io/reference/query-language/)
  - Always use parameterized queries to prevent injection and security issues
  - Validate and sanitize all user or external inputs
  - Document the purpose, expected behavior, and triggers for each reaction, source, or query
  - Prefer modular, reusable, and composable patterns for event-driven workflows
  - Apply the principle of least privilege for all access and role assignments
  - Test queries and logic with representative data, using Drasi-provided test harnesses or examples where possible

### Development Workflow for Queries
1. **Before writing any query**: Consult [https://drasi.io/reference/query-language/](https://drasi.io/reference/query-language/) for syntax and available functions
2. **During query development**: Reference the query language docs for proper function usage and patterns
3. **After query completion**: Validate against Drasi Query Language specification
4. **For complex queries**: Break down into smaller, testable components using DQL best practices

### Resource Priority Order
1. **[https://drasi.io/reference/query-language/](https://drasi.io/reference/query-language/)** - For ALL query-related work (PRIMARY)
2. **[https://drasi.io/](https://drasi.io/)** - For general concepts and architecture
3. **[Drasi GitHub repositories](https://github.com/orgs/drasi-project/repositories)** - For examples and templates
4. **Neo4j Cypher documentation** - Only as secondary reference for base Cypher concepts

- Reference and adapt the latest Drasi YAML templates and query examples from the official repositories

---

*These instructions ensure high-quality, maintainable, and secure Drasi configurations following the latest Drasi Query Language specification and community standards. Always prioritize the official query language reference for accurate, up-to-date syntax and functionality.*
