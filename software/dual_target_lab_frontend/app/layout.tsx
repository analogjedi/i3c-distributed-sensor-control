import type { Metadata } from "next";
import React from "react";

export const metadata: Metadata = {
  title: "Dual Target I3C Lab",
  description: "CMOD S7 dual-target I3C controller dashboard",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body
        style={{
          margin: 0,
          fontFamily: "Georgia, 'Times New Roman', serif",
          background:
            "radial-gradient(circle at top, #243b53 0%, #102a43 45%, #0b1f33 100%)",
          color: "#f0f4f8",
          minHeight: "100vh",
        }}
      >
        {children}
      </body>
    </html>
  );
}
