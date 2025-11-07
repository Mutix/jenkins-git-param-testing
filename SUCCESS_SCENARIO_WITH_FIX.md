# Success Scenario - With Fix (New Code)

This demonstrates the fix working correctly. JobA creates a new tag and immediately triggers JobB, and JobB succeeds because the cache is automatically refreshed when the tag is not found.

## Reproduction Steps

1. **Run JobA** (first time) - Creates tag and triggers JobB
   - ✅ JobB succeeds (no cache exists yet, so cache is populated fresh)

2. **Open JobB in Jenkins UI** - View the git parameter dropdown
   - This populates the `allowedValues` cache with existing tags
   - Cache now contains the first tag

3. **Run JobA again** (second time) - Creates a NEW tag and triggers JobB
   - ✅ Tag is successfully created and pushed to GitHub
   - ✅ **JobB succeeds** - Cache is automatically refreshed when tag not found
   - **The fix in action**: When validation doesn't find the tag in cache, it refreshes from git

## Console Output from JobA

```
Started by user unknown or anonymous
Obtained JobA-CreateTag.jenkinsfile from git https://github.com/Mutix/jenkins-git-param-testing
[Pipeline] Start of Pipeline
[Pipeline] node
Running on Jenkins in /Users/MOP07/Documents/Repos/OSS/Mutix/git-parameter-plugin/work/workspace/jobA
[Pipeline] {
[Pipeline] stage
[Pipeline] { (Declarative: Checkout SCM)
[Pipeline] checkout
Selected Git installation does not exist. Using Default
The recommended git tool is: NONE
No credentials specified
 > git rev-parse --resolve-git-dir /Users/MOP07/Documents/Repos/OSS/Mutix/git-parameter-plugin/work/workspace/jobA/.git # timeout=10
Fetching changes from the remote Git repository
 > git config remote.origin.url https://github.com/Mutix/jenkins-git-param-testing # timeout=10
Fetching upstream changes from https://github.com/Mutix/jenkins-git-param-testing
 > git --version # timeout=10
 > git --version # 'git version 2.39.5 (Apple Git-154)'
 > git fetch --tags --force --progress -- https://github.com/Mutix/jenkins-git-param-testing +refs/heads/*:refs/remotes/origin/* # timeout=10
 > git rev-parse origin/main^{commit} # timeout=10
Checking out Revision f1591c10dea8e83fc546b2f54a210271867cd196 (origin/main)
 > git config core.sparsecheckout # timeout=10
 > git checkout -f f1591c10dea8e83fc546b2f54a210271867cd196 # timeout=10
Commit message: "test setup"
 > git rev-list --no-walk f1591c10dea8e83fc546b2f54a210271867cd196 # timeout=10
[Pipeline] }
[Pipeline] // stage
[Pipeline] withEnv
[Pipeline] {
[Pipeline] stage
[Pipeline] { (Checkout Repository)
[Pipeline] script
[Pipeline] {
[Pipeline] echo
Checking out test repository
[Pipeline] sh
+ rm -rf test-repo
+ git clone https://github.com/Mutix/jenkins-git-param-testing.git test-repo
Cloning into 'test-repo'...
+ cd test-repo
+ git config user.email test@example.com
+ git config user.name 'Test User'
[Pipeline] }
[Pipeline] // script
[Pipeline] }
[Pipeline] // stage
[Pipeline] stage
[Pipeline] { (Create and Push New Tag)
[Pipeline] script
[Pipeline] {
[Pipeline] echo
Creating new tag: test-tag-1762473198628
[Pipeline] sh
+ cd test-repo
+ git tag test-tag-1762473198628
+ git push origin test-tag-1762473198628
To https://github.com/Mutix/jenkins-git-param-testing.git
 * [new tag]         test-tag-1762473198628 -> test-tag-1762473198628
+ echo 'Successfully created and pushed tag: test-tag-1762473198628'
Successfully created and pushed tag: test-tag-1762473198628
[Pipeline] }
[Pipeline] // script
[Pipeline] }
[Pipeline] // stage
[Pipeline] stage
[Pipeline] { (Trigger Downstream Build)
[Pipeline] echo
Triggering Job B with tag: test-tag-1762473198628
[Pipeline] build (Building jobB)
Scheduling project: jobB
Starting building: jobB #4
Build jobB #4 completed: SUCCESS
[Pipeline] }
[Pipeline] // stage
[Pipeline] stage
[Pipeline] { (Declarative: Post Actions)
[Pipeline] echo
✅ Successfully created tag test-tag-1762473198628 and triggered downstream build
[Pipeline] }
[Pipeline] // stage
[Pipeline] }
[Pipeline] // withEnv
[Pipeline] }
[Pipeline] // node
[Pipeline] End of Pipeline
Finished: SUCCESS
```

**Result:** `SUCCESS` ✅

## What Happened

1. ✅ JobA successfully created tag `test-tag-1762473198628`
2. ✅ JobA successfully pushed tag to GitHub
3. ✅ JobA triggered JobB with parameter `GIT_TAG=test-tag-1762473198628`
4. ✅ **JobB validation succeeded** - Cache was refreshed automatically
5. ✅ JobB build completed successfully

## How the Fix Works

The git parameter in JobB has a cached list of allowed values (tags) that was populated when the user opened JobB's configuration page in the Jenkins UI (step 2 of reproduction). This cache is stored in the `allowedValues` transient field.

When JobB receives the parameter value `test-tag-1762473198628` from the downstream build trigger:

1. The `isValid()` method checks if the value exists in the cache
2. The cache exists (populated in step 2) but doesn't contain the newly created tag (it's stale)
3. **The new code detects cache miss and refreshes the cache from git**
4. After refresh, the tag is found in the updated cache
5. Validation succeeds ✅


## Comparison: Before vs After

| Scenario | Before Fix | After Fix |
|----------|-----------|-----------|
| First JobA run (no cache) | ✅ Success | ✅ Success |
| After viewing UI (cache populated) | Cache exists | Cache exists |
| Second JobA run (new tag) | ❌ **FAILURE** - "Invalid parameter value" | ✅ **SUCCESS** - Cache refreshed |
| Invalid tag | ✅ Rejected | ✅ Rejected (security maintained) |

## Test Environment

- **Jenkins Version:** 2.479.3
- **Git Parameter Plugin:** https://github.com/jenkinsci/git-parameter-plugin/commit/057718d49b8a5bf2865c02ca23f8364ab4ae27bd
- **Test Repository:** https://github.com/Mutix/jenkins-git-param-testing
- **Tag Created:** `test-tag-1762473198628`
- **Trigger Method:** Pipeline `build` step (downstream build)

## Related Issues

- [JENKINS-76158](https://issues.jenkins.io/browse/JENKINS-76158) - Valid branch git parameter gets error as invalid when scheduled via Jenkins API
- [JENKINS-75977](https://issues.jenkins.io/browse/JENKINS-75977) - Invalid parameter value when trying to build a job against a new branch

