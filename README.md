# Container Diff Report Action

[![GitHub release](https://img.shields.io/github/release/framjet/container-diff-report-action.svg)](https://github.com/framjet/container-diff-report-action/releases)
[![License](https://img.shields.io/github/license/framjet/container-diff-report-action.svg)](LICENSE)

A GitHub Action that compares two container images using [container-diff](https://github.com/GoogleContainerTools/container-diff) and generates a detailed markdown diff report.

## Features

- 📦 **Automated Setup**: Downloads and configures container-diff automatically
- 🔍 **Detailed Analysis**: Shows added, deleted, and modified files with sizes
- 📝 **File Diffs**: Displays actual diff content for modified files
- 📊 **Rich Output**: Generates markdown reports for documentation or comments

## Usage

### Basic Example

```yaml
name: Container Diff Analysis

on:
  workflow_dispatch:
    inputs:
      image1:
        description: 'First image to compare'
        required: true
        default: 'myapp:v1.1.0'
      image2:
        description: 'Second image to compare'
        required: true
        default: 'myapp:v1.0.0'

jobs:
  container-diff:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run container diff
        id: diff
        uses: framjet/container-diff-action@v1
        with:
          image1: ${{ github.event.inputs.image1 }}
          image2: ${{ github.event.inputs.image2 }}

      - name: Display results
        run: |
          echo "Changes detected: ${{ steps.diff.outputs.has-changes }}"
          echo "Report file: ${{ steps.diff.outputs.report-file }}"

      - name: Upload report
        uses: actions/upload-artifact@v3
        with:
          name: container-diff-report
          path: ${{ steps.diff.outputs.report-file }}
```

### Compare Release Images

```yaml
name: Compare Release Images

on:
  release:
    types: [ published ]

jobs:
  compare-releases:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Get previous release
        id: previous-release
        uses: actions/github-script@v6
        with:
          script: |
            const releases = await github.rest.repos.listReleases({
              owner: context.repo.owner,
              repo: context.repo.repo,
              per_page: 2
            });
            const previousRelease = releases.data[1];
            core.setOutput('tag', previousRelease ? previousRelease.tag_name : 'main');

      - name: Compare container images
        id: diff
        uses: framjet/container-diff-action@v1
        with:
          image1: myregistry.com/myapp:${{ github.event.release.tag_name }}
          image2: myregistry.com/myapp:${{ steps.previous-release.outputs.tag }}

      - name: Create release notes
        if: steps.diff.outputs.has-changes == 'true'
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const diffReport = fs.readFileSync('${{ steps.diff.outputs.report-file }}', 'utf8');

            await github.rest.repos.updateRelease({
              owner: context.repo.owner,
              repo: context.repo.repo,
              release_id: ${{ github.event.release.id }},
              body: `${{ github.event.release.body }}\n\n${diffReport}`
            });
```

### Scheduled Comparison

```yaml
name: Daily Image Comparison

on:
  schedule:
    - cron: '0 9 * * 1-5'  # Weekdays at 9 AM
  workflow_dispatch:

jobs:
  daily-diff:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Compare staging vs production
        id: diff
        uses: framjet/container-diff-action@v1
        with:
          image1: myapp:staging
          image2: myapp:production
          registry-username: ${{ secrets.DOCKER_USERNAME }}
          registry-password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Send Slack notification
        if: steps.diff.outputs.has-changes == 'true'
        uses: 8398a7/action-slack@v3
        with:
          status: custom
          custom_payload: |
            {
              text: "Container differences detected between staging and production",
              attachments: [{
                color: "warning",
                fields: [{
                  title: "Diff Report",
                  value: "Check the workflow artifacts for detailed comparison"
                }]
              }]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

      - name: Upload diff report
        uses: actions/upload-artifact@v3
        with:
          name: staging-vs-production-diff
          path: ${{ steps.diff.outputs.report-file }}
```

## Inputs

| Input                | Description                                     | Required | Default                             |
|----------------------|-------------------------------------------------|----------|-------------------------------------|
| `image1`             | First container image to compare                | ✅        | -                                   |
| `image2`             | Second container image to compare               | ✅        | -                                   |
| `allowed-extensions` | Comma-separated list of file extensions to diff | ❌        | Common source code extensions* [^1] |
| `max-file-size`      | Maximum file size in bytes to diff              | ❌        | `1048576` (1 MB)                    |
| `render-html`        | Also render report as HTML                      | ❌        | `false`                             |

[^1]: Default allowed extensions include: `js,ts,jsx,tsx,py,go,java,kt,swift,rb,php,c,cpp,h,hpp,cs,rs,scala,clj,sh,bash,zsh,fish,ps1,bat,cmd,dockerfile,makefile,cmake,yaml,yml,json,xml,toml,ini,cfg,conf,config,properties,env,sql,md,txt,html,css,scss,sass,less,vue,svelte,dart,lua,r,pl,pm,ex,exs,erl,hrl,elm,hs,lhs,ml,mli,fs,fsx,fsi,vb,asm,s,m,mm,plist`

## Outputs

| Output             | Description                                  | Example                                |
|--------------------|----------------------------------------------|----------------------------------------|
| `diff-report`      | Complete markdown diff report                | `## 📦 Container Image Diff Report...` |
| `has-changes`      | Whether changes were detected between images | `true` / `false`                       |
| `report-file`      | Path to generated markdown report file       | `container-diff-report.md`             |
| `report-file-html` | Path to generated html report file           | `container-diff-report.html`           |

## Sample Output

The action generates a comprehensive markdown report like this:

````markdown
## 📦 Container Image Diff Report

**Images compared:**

- **Image 1:** `myapp:v1.1.0`
- **Image 2:** `myapp:v1.0.0`

### Summary

- ✅ **Added:** 5 files
- ❌ **Deleted:** 2 files
- 📝 **Modified:** 8 files

### ✅ Added Files
```

/app/new-feature.js (2048 bytes)
/app/config/new-config.json (512 bytes)
/app/assets/logo.png (4096 bytes)
/app/migrations/001_add_users.sql (1024 bytes)
/usr/local/bin/healthcheck (512 bytes)

```

### ❌ Deleted Files
```

/app/old-legacy.js (1024 bytes)
/tmp/build-cache (8192 bytes)

```

### 📝 Modified Files

**Modified files:**
```

/app/package.json (1234 → 1456 bytes)
/app/src/main.js (5678 → 6789 bytes)
/app/Dockerfile (2048 → 2156 bytes)
/etc/nginx/nginx.conf (4096 → 4200 bytes)

```

#### `/app/package.json`
<details>
<summary>Show diff</summary>

```diff
--- myapp:v1.0.0
+++ myapp:v1.1.0
@@ -15,6 +15,8 @@
   "dependencies": {
     "express": "^4.18.0",
+    "lodash": "^4.17.21",
+    "axios": "^1.4.0",
     "body-parser": "^1.20.0"
   }
```

</details>

#### `/app/src/main.js`

<details>
<summary>Show diff</summary>

```diff
--- myapp:v1.0.0
+++ myapp:v1.1.0
@@ -1,5 +1,6 @@
 const express = require('express');
 const bodyParser = require('body-parser');
+const axios = require('axios');
 
 const app = express();
 app.use(bodyParser.json());
@@ -10,6 +11,11 @@
   res.json({ message: 'Hello World' });
 });
 
+app.get('/api/status', async (req, res) => {
+  const status = await checkServiceHealth();
+  res.json({ status });
+});
+
 app.listen(3000, () => {
   console.log('Server running on port 3000');
 });
```

</details>
````

## Use Cases

- **Release Analysis**: Compare what changed between releases
- **Security Auditing**: Track file changes across builds
- **Debugging**: Understand deployment differences
- **Documentation**: Generate change reports for releases
- **CI/CD Validation**: Verify expected changes in builds
- **Monitoring**: Detect unexpected changes in images

## Requirements

- Linux runner (ubuntu-latest recommended)
- Docker available on runner
- Images must be pullable by the runner

## Troubleshooting

### Common Issues

**Image not found**

```
Error: Could not pull image1
```

- Verify image names and tags are correct
- Check registry authentication
- Ensure images exist in the registry

**Permission denied**

```
Error: permission denied while trying to connect to Docker daemon
```

- Use ubuntu-latest or another runner with Docker pre-installed
- Ensure the runner has Docker daemon access

**Large diff output**

- The action handles large outputs by saving to files
- Use artifacts to store reports for large diffs
- Consider filtering specific file types if needed

### Debug Mode

Enable debug logging by setting:

```yaml
env:
  ACTIONS_STEP_DEBUG: true
```


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
