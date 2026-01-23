/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./index.html",
    "./index.tsx",
    "./App.tsx",
    "./components/**/*.{ts,tsx}",
    "./services/**/*.{ts,tsx}",
    "./styles/**/*.css",
  ],
  theme: {
    extend: {
      colors: {
        bitcoin: "#f7931a",
        "bitcoin-dark": "#e88310",
        background: "#0b0f14",
        "background-accent": "#101823",
        surface: {
          100: "#111827",
          200: "#141c27",
          300: "#1f2937",
        },
        border: "#2a3442",
        muted: "#9aa6b2",
        success: "#22c55e",
        error: "#ef4444",
        warning: "#f59e0b",
      },
      borderRadius: {
        "4xl": "2rem",
        "5xl": "3rem",
      },
      fontFamily: {
        sans: ["Inter", "ui-sans-serif", "system-ui", "sans-serif"],
        mono: ["JetBrains Mono", "ui-monospace", "SFMono-Regular", "monospace"],
      },
      letterSpacing: {
        "super-wide": "0.2em",
        "mega-wide": "0.3em",
      },
      boxShadow: {
        "custom-bitcoin": "0 0 15px rgba(247, 147, 26, 0.4)",
      },
    },
  },
  plugins: [],
};
