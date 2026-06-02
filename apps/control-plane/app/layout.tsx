import "./globals.css";
import type { Metadata } from "next";
import type { ReactNode } from "react";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Conxian BOS Control Plane",
  description: "Private BOS control-plane for governance, audit, release, and policy workflows.",
};

const navItems = [
  { href: "/", label: "Overview" },
  { href: "/release-governance", label: "Release governance" },
  { href: "/audit", label: "Audit" },
  { href: "/policy-approvals", label: "Policy approvals" },
  { href: "/environments", label: "Environments" },
];

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        <div className="app-frame">
          <aside className="sidebar">
            <div>
              <p className="eyebrow">Conxian</p>
              <h1 className="sidebar-title">BOS Control Plane</h1>
              <p className="muted small">Private governance and operations surface.</p>
            </div>

            <nav>
              <ul className="nav-list">
                {navItems.map((item) => (
                  <li key={item.href}>
                    <Link className="nav-link" href={item.href}>
                      {item.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </nav>
          </aside>

          <div className="content-shell">{children}</div>
        </div>
      </body>
    </html>
  );
}
