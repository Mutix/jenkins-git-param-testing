# Testing Instructions for Git Parameter Plugin Fix

This guide walks you through testing the stale cache fix locally.

## Prerequisites

### 1. Fork the Test Repository

**Important:** You need to fork the test repository to push tags during testing.

1. Fork https://github.com/Mutix/jenkins-git-param-testing to your own GitHub account
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/jenkins-git-param-testing.git /tmp/test-git-work
   cd /tmp/test-git-work
   git config user.email "test@example.com"
   git config user.name "Test User"
   ```
3. **Update repository URLs** in the pipeline scripts:
   - In `JobA-CreateTag.jenkinsfile`: Replace `https://github.com/Mutix/jenkins-git-param-testing.git` with your fork URL
   - In `JobB-UseTag.jenkinsfile`: Replace `https://github.com/Mutix/jenkins-git-param-testing.git` with your fork URL

**Alternative:** If you want to test with the original repository, contact the maintainer for write access to push tags.

### 2. Build and Start Jenkins

```bash
# From the git-parameter-plugin directory
mvn clean package -DskipTests  # Build the plugin
mvn hpi:run                    # Starts Jenkins on http://localhost:8080/jenkins
```

### 3. Wait for Jenkins to Start

Wait for Jenkins to start (watch for "Jenkins is fully up and running")

### 4. Open Jenkins in Browser

Open browser to `http://localhost:8080/jenkins`

### 5. Install Pipeline: Build Step Plugin

**Required for the `build` step:**
- Go to **Manage Jenkins** → **Manage Plugins**
- Click **Available plugins** tab
- Search for: `Pipeline: Build Step`
- Check the box and click **Install without restart**
- Wait for installation to complete

## Step 1: Create Job A (Tag Creator)

1. Click **New Item**
2. Name: `JobA`
3. Type: **Pipeline**
4. Click **OK**
5. In the Pipeline section:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/Mutix/jenkins-git-param-testing.git` (use your fork URL)
   - Branch Specifier: `*/main`
   - Script Path: `JobA-CreateTag.jenkinsfile`
6. Click **Save**

## Step 2: Create Job B (Tag Consumer)

1. Click **New Item**
2. Name: `JobB`
3. Type: **Pipeline**
4. Click **OK**

### Configure Git Parameter:

5. Check ✅ **This project is parameterized**
6. Click **Add Parameter** → **Git Parameter**
7. Configure the parameter:
   - **Name**: `GIT_TAG`
   - **Parameter Type**: `Tag`
   - **Repository URL**: `https://github.com/Mutix/jenkins-git-param-testing.git` (use your fork URL)
   - **Sort Mode**: `DESCENDING_SMART` (optional)
   - **Default Value**: (leave empty)
   - **Branch**: (leave empty)

### Configure Pipeline:

8. Scroll down to **Pipeline** section:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/Mutix/jenkins-git-param-testing.git` (use your fork URL)
   - Branch Specifier: `*/main`
   - Script Path: `JobB-UseTag.jenkinsfile`
9. Click **Save**

## Step 3: Test the Fix

### Test 1: Verify Job B Works with Existing Tag

1. Go to **JobB**
2. Click **Build with Parameters**
3. Select any existing tag from the dropdown (your fork should have at least one tag)
4. Click **Build**
5. **Expected**: ✅ Build succeeds

### Test 2: Reproduce the Bug Scenario (Main Test)

1. Go to **JobA**
2. Click **Build Now**
3. Watch the console output:
   - Stage 1: Creates a new tag (e.g., `test-tag-1730934567890`)
   - Stage 2: Triggers JobB with the new tag
4. JobB will be triggered automatically
5. Go to **JobB** and check the latest build

**Expected Results:**

**WITH FIX (current code):**
- ✅ JobB succeeds
- Console shows: "✅ Tag parameter validated successfully: test-tag-XXXXX"
- Console shows: "✅ Successfully built with tag: test-tag-XXXXX"

**WITHOUT FIX:**
- ❌ JobB fails immediately
- Error: "ERROR: Invalid parameter value: test-tag-XXXXX"
- The validation rejects the tag because it's not in the stale cache

### Test 3: Verify Cache Refresh Works Multiple Times

1. Run **JobA** again (creates another new tag)
2. Verify **JobB** succeeds again
3. Repeat 2-3 times to ensure consistency

## Step 4: Verify the Fix Behavior

### What's Happening Under the Hood:

1. **JobA creates tag** → Git repository now has `test-tag-1234567890`
2. **JobA triggers JobB** → Passes `GIT_TAG=test-tag-1234567890`
3. **JobB parameter validation** (`isValid()` method):
   - Cache exists but doesn't contain the new tag (stale cache)
   - **OLD CODE**: Returns false → Build fails
   - **NEW CODE**: Refreshes cache from git → Finds tag → Returns true → Build succeeds ✅

### Verify in Logs:

Check JobB's console output for:
```
Received GIT_TAG parameter: test-tag-XXXXX
✅ Tag parameter validated successfully: test-tag-XXXXX
```

If you see this, the cache refresh on miss is working!

## Step 5: Test Edge Cases

### Test Invalid Tag (Security Check):

1. Go to **JobB**
2. Click **Build with Parameters**
3. Manually type an invalid tag: `malicious-tag-12345`
4. Click **Build**
5. **Expected**: ❌ Build fails with "Invalid parameter value"
   - This proves SECURITY-3419 protections are still working

### Test with Branch Parameter:

1. Edit **JobB** → Configure
2. Change Git Parameter:
   - **Parameter Type**: `Branch` (instead of Tag)
3. Save
4. Modify **JobA** to create branches instead of tags:
```groovy
git checkout -b "test-branch-${timestamp}"
git push origin "test-branch-${timestamp}"
```
5. Run the same tests - should work for branches too

## Troubleshooting

### JobA fails to push tags

**Error: "Permission denied" or "Authentication failed"**

You need push access to the repository. Either:
1. Use your own fork (recommended)
2. Set up GitHub credentials in Jenkins:
   - Go to **Manage Jenkins** → **Credentials**
   - Add GitHub username/password or personal access token
   - Update JobA to use credentials when cloning

### JobA fails with "No such DSL method 'build'"

Install the Pipeline: Build Step plugin (see Prerequisites step 5).

## Success Criteria

✅ JobB succeeds when triggered by JobA with newly created tag  
✅ JobB fails when given an invalid/non-existent tag  
✅ Multiple consecutive runs of JobA → JobB all succeed  
✅ Existing tests still pass: `mvn clean test`

