import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/hooks/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        bg: "var(--bg)",
        surface: "var(--surface)",
        "surface-2": "var(--surface-2)",
        "surface-3": "var(--surface-3)",
        tx: "var(--text)",
        "tx-muted": "var(--text-muted)",
        bd: "var(--border)",
        accent: "var(--accent)",
        "accent-hover": "var(--accent-hover)",
        "accent-active": "var(--accent-active)",
        "accent-bg": "var(--accent-bg)",
        "accent-bg-strong": "var(--accent-bg-strong)",
        brand: {
          orange: "#DA7500",
          orangeHover: "#EB8C1F",
          orangeActive: "#C56500",
          coral: "#ff6740",
        },
        pal: {
          purple: "var(--purple)",
          cyan: "var(--cyan)",
          sky: "var(--sky)",
          green: "var(--green)",
          amber: "var(--amber)",
          red: "var(--red)",
          blue: "var(--blue)",
        },
        /* legacy compat */
        neutral: {
          charcoal: "#242424",
          dark: "#222222",
          line: "var(--border)",
          altLine: "var(--border)",
          soft: "var(--surface-2)",
        },
        semantic: {
          error: "var(--red)",
          warning: "var(--amber)",
        },
      },
      fontFamily: {
        heading: ["var(--font-heading)"],
        body: ["var(--font-body)"],
      },
      boxShadow: {
        card: "var(--shadow-card)",
        "card-hover": "var(--shadow-card-hover)",
        floating: "var(--shadow-floating)",
        manga: "var(--shadow-card)",
        "manga-hover": "var(--shadow-card-hover)",
      },
      borderRadius: {
        def: "var(--radius)",
        sm: "var(--radius-sm)",
        lg: "var(--radius-lg)",
      },
      spacing: {
        18: "4.5rem",
        30: "7.5rem",
      },
      maxWidth: {
        content: "1440px",
        readable: "860px",
      },
    },
  },
  plugins: [],
};

export default config;
