import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: "#F0455A",
          deep: "#9E1F3E",
          soft: "#F8B9C6",
          blush: "#FDEDF0",
        },
        accent: "#FFD54A",
        ink: "#4B1528",
        ivory: "#FFF8F6",
      },
      boxShadow: {
        card: "0 8px 30px rgba(240, 69, 90, 0.12)",
        lift: "0 12px 40px rgba(158, 31, 62, 0.16)",
      },
      borderRadius: {
        card: "1.5rem",
      },
      fontFamily: {
        sans: [
          "Pretendard Variable",
          "Pretendard",
          "-apple-system",
          "BlinkMacSystemFont",
          "system-ui",
          "sans-serif",
        ],
      },
    },
  },
  plugins: [],
};
export default config;
