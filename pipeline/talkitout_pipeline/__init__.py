"""Talk It Out Python NLP rewrite worker.

Talks to the backend exclusively through the HTTP contract in
backend/docs/groups-pipeline-contract.md (contract_version 1). Never
touches the database. Never logs message text, sender identity, or
secrets. See ../AGENTS.md for the component's rules.
"""

PIPELINE_COMPONENT_VERSION = "0.1.0"
