# Failing Scenario - Before Fix (Old Code)

This demonstrates the bug where JobA creates a new tag and immediately triggers JobB, but JobB fails with "Invalid parameter value" because the git parameter cache is stale.

## Reproduction Steps

1. **Run JobA** (first time) - Creates tag and triggers JobB
   - ✅ JobB succeeds (no cache exists yet, so cache is populated fresh)

2. **Open JobB in Jenkins UI** - View the git parameter dropdown
   - This populates the `allowedValues` cache with existing tags
   - Cache now contains the first tag but is "frozen"

3. **Run JobA again** (second time) - Creates a NEW tag and triggers JobB
   - ✅ Tag is successfully created and pushed to GitHub
   - ❌ **JobB fails** with "Invalid parameter value"
   - **Root cause**: Cache was populated in step 2, doesn't contain the new tag, and old code doesn't refresh it

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
Creating new tag: test-tag-1762473037224
[Pipeline] sh
+ cd test-repo
+ git tag test-tag-1762473037224
+ git push origin test-tag-1762473037224
To https://github.com/Mutix/jenkins-git-param-testing.git
 * [new tag]         test-tag-1762473037224 -> test-tag-1762473037224
+ echo 'Successfully created and pushed tag: test-tag-1762473037224'
Successfully created and pushed tag: test-tag-1762473037224
[Pipeline] }
[Pipeline] // script
[Pipeline] }
[Pipeline] // stage
[Pipeline] stage
[Pipeline] { (Trigger Downstream Build)
[Pipeline] echo
Triggering Job B with tag: test-tag-1762473037224
[Pipeline] build (Building jobB)
Scheduling project: jobB
[Pipeline] }
[Pipeline] // stage
[Pipeline] stage
[Pipeline] { (Declarative: Post Actions)
[Pipeline] echo
❌ Failed to create tag or trigger downstream build
[Pipeline] }
[Pipeline] // stage
[Pipeline] }
[Pipeline] // withEnv
[Pipeline] }
[Pipeline] // node
[Pipeline] End of Pipeline
```

## Error Details

```
hudson.remoting.ProxyException: hudson.AbortException: Invalid parameter value: (StringParameterValue) GIT_TAG='test-tag-1762473037224'
	at PluginClassLoader for pipeline-build-step//org.jenkinsci.plugins.workflow.support.steps.build.BuildTriggerStepExecution.completeDefaultParameters(BuildTriggerStepExecution.java:202)
	at PluginClassLoader for pipeline-build-step//org.jenkinsci.plugins.workflow.support.steps.build.BuildTriggerStepExecution.start(BuildTriggerStepExecution.java:105)
	at PluginClassLoader for workflow-cps//org.jenkinsci.plugins.workflow.cps.DSL.invokeStep(DSL.java:323)
	at PluginClassLoader for workflow-cps//org.jenkinsci.plugins.workflow.cps.DSL.invokeMethod(DSL.java:196)
	at PluginClassLoader for workflow-cps//org.jenkinsci.plugins.workflow.cps.CpsScript.invokeMethod(CpsScript.java:124)
	...
```

**Result:** `FAILURE`

## What Happened

1. ✅ JobA successfully created tag `test-tag-1762473037224`
2. ✅ JobA successfully pushed tag to GitHub
3. ✅ JobA triggered JobB with parameter `GIT_TAG=test-tag-1762473037224`
4. ❌ **JobB validation failed** with "Invalid parameter value"

## Root Cause

The git parameter in JobB has a cached list of allowed values (tags) that was populated when the user opened JobB's configuration page in the Jenkins UI (step 2 of reproduction). This cache is stored in the `allowedValues` transient field.

When JobB receives the parameter value `test-tag-1762473037224` from the downstream build trigger:

1. The `isValid()` method checks if the value exists in the cache
2. The cache exists (populated in step 2) but doesn't contain the newly created tag (it's stale)
3. **The old code doesn't refresh the cache when a value is not found in an existing cache**
4. Validation fails with "Invalid parameter value"

**Key insight:** The first run of JobA succeeds because no cache exists yet (`allowedValues == null`), so the cache is populated fresh. The second run fails because the cache exists but is stale.

## Test Environment

- **Jenkins Version:** 2.479.3
- **Git Parameter Plugin:** aa3301f
- **Test Repository:** https://github.com/Mutix/jenkins-git-param-testing
- **Tag Created:** `test-tag-1762473037224`
- **Trigger Method:** Pipeline `build` step (downstream build)


## Related Issues

- [JENKINS-76158](https://issues.jenkins.io/browse/JENKINS-76158) - Valid branch git parameter gets error as invalid when scheduled via Jenkins API
- [JENKINS-75977](https://issues.jenkins.io/browse/JENKINS-75977) - Invalid parameter value when trying to build a job against a new branch

