# Project Repository

This is the initial README file for the project.

## Environment variables

This repository uses multiple containers (frontend, backend, and database tooling), each with its own environment variables. For a complete list of required and optional variables, their purpose, and the exact code locations where they are read, see `kavia-docs/ENVIRONMENT.md`.

The database container’s local tooling also includes a small “db_visualizer” service which reads database connection information from environment variables.