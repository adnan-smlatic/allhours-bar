import type { Metadata, Viewport } from "next";
import { Archivo, Doto, IBM_Plex_Mono } from "next/font/google";
import { site } from "@/site.config";
import "./globals.css";

const archivo = Archivo({
  subsets: ["latin", "latin-ext"],
  axes: ["wdth"],
  variable: "--font-archivo",
  display: "swap",
});

const doto = Doto({
  subsets: ["latin"],
  weight: "800",
  variable: "--font-doto",
  display: "swap",
});

const plexMono = IBM_Plex_Mono({
  subsets: ["latin"],
  weight: ["400", "500"],
  variable: "--font-plex-mono",
  display: "swap",
});

const description =
  "A free, open-source macOS menu bar app for All Hours attendance. See if you're clocked in, clock in or out in one click, and get reminded when you forget.";

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: `${site.name}: All Hours attendance in your Mac menu bar`,
  description,
  openGraph: { title: site.name, description, type: "website" },
  twitter: { card: "summary_large_image", title: site.name, description },
};

export const viewport: Viewport = {
  themeColor: "#4f6076",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${archivo.variable} ${doto.variable} ${plexMono.variable}`}>
      <body className="font-sans">{children}</body>
    </html>
  );
}
