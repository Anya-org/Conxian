# 12-Month Control-Plane Roadmap

## 0-30 days
- Freeze repo roles and boundaries
- Publish target architecture and ADRs
- Scaffold `apps/control-plane`
- Add shared package skeletons
- Define initial admin API contracts

## 30-90 days
- Stand up the internal control-plane shell
- Define route map for release governance, audit, policy approvals, and environment registry
- Align shared schema package with the first module set
- Define dependency boundaries with `conxian-nexus` and `conxian-gateway`

## 3-6 months
- Implement first control-plane modules
- Introduce internal auth/RBAC model
- Add audit event visibility and operator workflows
- Formalize release discipline and change management views

## 6-9 months
- Expand runtime integrations through stable admin APIs
- Improve observability and operational dashboards
- Reduce duplication across docs, control-plane logic, and runtime contracts

## 9-12 months
- Harden for partner and auditor workflows
- Publish clearer internal platform operating model
- Mature release governance and compliance evidence collection
- Prepare adjacent repos for more explicit product/runtime contracts

## Related issues
- #710
- #711
- #712
- #713
- #714
- #715
