# Production Readiness Report – Analyst UI

## Summary

This report evaluates the readiness level of the Analyst UI applications (Web, iOS, Android) as a deliverable for NGA, and whether the codebases are maintainable by a human team.

**Overall conclusion:** the system is not production-ready today. The client applications, especially the web app, have critical misses in configuration management, security, and operational readiness.

---

## Readiness Score

| Category                 | Status                               |
| ------------------------ | ------------------------------------ |
| **Production Readiness** | Not Ready                            |
| **Maintainability**      | Possible with cleanup                |
| **Operational Risk**     | High until critical issues are fixed |

---

## What Is Working Well

- The Apps have an easy to follow UX
- Modern technologies with a logical directory structure
- Lots of comments and documentation files

---

## Must Be Fixed Before Shipping the Web App

### Hardcoded Environment Configuration

Obviously this is because the apps are currently in development but an effort will need to be made to make sure this is updated for shipping, or at least configurable for the user, depending on how we ship this.

### Sensitive Logging

All of the app clients log URLs, cookies, or request details. This exposes things like credentials and internal data to the browser and the end user. Logging must be cleaned up and/or gated and sanitized.

### Input Validation

The web app sends some unvalidated queries to the back end. Even though the backend does some validation of its own, this is a stability risk.

### Security Misses

One big example I found is that the web app accepts a userId parameter even though the backend ignores it and uses the session. This exposes sensitive data that isn't necessary or best practice. This is just one example of this type of query handling in the front end, but it is possible there are other examples that I haven't found yet.

### HTTPS and Security Header Enforcement

Some HTTPS headers are not enforced on the front end, which can cause issues in production.

### Dead and Divergent Code

This is the one that makes these hard to maintain. There are multiple diverging strategies (I counted at least 3) for code implementation which, in at least a few cases, left dead or redundant code behind. Code implementation should be as homogeneous as possible for scalability and maintainability. There are some cases of components that are unused or even created multiple different times instead of something that is reusable.

### Placeholder Content

I discovered some placeholder content for links and variables that don't lead anywhere or, even worse, allow the user to interact with things that doesn't actually work (eg. configuring email notifications). There is probably a lot more of this we haven't discovered. We would need to be diligent in making sure the codebase is clear of these kinds of placeholders as many seem innocuous but are easy to miss and will be problems for the user eventually.

---

## Readiness by Application

### analyst-ui-web

| Attribute             | Value                                              |
| --------------------- | -------------------------------------------------- |
| **Release readiness** | Low                                                |
| **Primary risks**     | Security, configuration, and operational hardening |

This app does a lot of things well but there are some large gaps under the hood. Today it lacks some basic protections: input validation, proper error handling, and environment-based configuration. There are also some areas of inefficiency that would make updating or maintaining this difficult.

### analyst-ui-ios

| Attribute             | Value                                          |
| --------------------- | ---------------------------------------------- |
| **Release readiness** | Moderate                                       |
| **Primary risks**     | Configuration management and release hardening |

Architecture looks good. Need to remove hardcoded configuration, make sure secure token storage settings are correct, and disable debug logging for a release build. This is a less in-depth audit than the web client application.

### analyst-ui-android

| Attribute             | Value                                                          |
| --------------------- | -------------------------------------------------------------- |
| **Release readiness** | Low                                                            |
| **Primary risks**     | Configuration management, logging, and release build hardening |

Architecture looks good. This app seems like it needs some more work if it were to be released, so the audit on this one was not as in-depth.

---

## Maintainability

Overall maintainability is possible but may be trickier than a simple audit can uncover. The codebases use modern technologies and patterns but there are some things that are confusing and inefficient for humans. These issues will definitely cause problems for maintainability if not addressed:

- There is noticeable AI-generated code causing diverging implementation strategies
- There is inefficient code duplication
- There is some dead code and unused components
- There is insufficient high-level documentation of architecture and intent

Without a lot of cleanup this will be a headache to maintain, as the diverging implementations alone will make it difficult to find the cause of some bugs or implement new features in a scalable way.

---

## Minimum Actions Required Before NGA Release

1. Move all environment-specific configuration (URLs, etc.) to environment/build config in all apps
2. Remove or gate all debug and sensitive logging
3. Add strict input validation
4. Fix userId parameter handling in the web app
5. Enforce HTTPS and security headers
6. Refactor dead code and duplicated logic in the web app (if we don't plan to maintain/iterate on the web app then I guess this could be optional, but it could have unforeseen consequences down the line)

---

## Conclusion

The web app and overall deployment are not yet suitable for customer-facing production use. Building on a solid back end foundation with Server helps, but does not mitigate the risks outlined in this report.
