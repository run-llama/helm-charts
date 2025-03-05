# Helm Chart Downgrade Runbook

Upgrading this helm chart is the same as upgrading any helm chart:
```shell
helm -n <namespace> upgrade llamacloud llamaindex/llamacloud -f values.yaml --version <chart-version>
```

However, an extra step would be required for *downgrades*. This is primarly because the postgres database schemas will need to be migrated back to the versions they were at in the helm chart you are aiming to downgrade to.
At a high level, you will first need to run this alembic downgrade within your deployment pod before being able to run the full helm-chart downgrade.

For this, we've provided a utility script in this repo named [`helm_chart_alembic_version.sh`](../scripts/helm_chart_alembic_version.sh). Each helm chart is on a specific alembic migration version which indicates the state of the postgres database schema at the point in time the specific helm chart version was created.
This script will simply print out this alembic migration version for a given helm chart version. Once you have this, you may copy the alembic version it prints out and continue with these following steps:
1. TODO
