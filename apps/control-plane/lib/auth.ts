export type ControlPlaneRole = "viewer" | "operator" | "approver" | "admin";

export interface AuthenticatedActor {
  id: string;
  name: string;
  role: ControlPlaneRole;
}

export function getCurrentActor(): AuthenticatedActor {
  return {
    id: "bootstrap-actor",
    name: "Bootstrap Operator",
    role: "admin",
  };
}

export function canRead(role: ControlPlaneRole): boolean {
  return ["viewer", "operator", "approver", "admin"].includes(role);
}

export function canApprove(role: ControlPlaneRole): boolean {
  return ["approver", "admin"].includes(role);
}

export function canOperate(role: ControlPlaneRole): boolean {
  return ["operator", "approver", "admin"].includes(role);
}
