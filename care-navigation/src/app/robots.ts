import type { MetadataRoute } from "next";
import { TODO_COMPANY } from "@/lib/constants";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: "*", allow: "/" },
    sitemap: `${TODO_COMPANY.siteUrl}/sitemap.xml`,
  };
}
