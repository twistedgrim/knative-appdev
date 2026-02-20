# hello-func

Sample function source directory used by `scripts/func-build-deploy.sh`.

Create a function here with:

```bash
func create -l node hello-func
```

Then run from repo root:

```bash
APP_DIR=src/functions/hello-func ./scripts/func-build-deploy.sh
```
