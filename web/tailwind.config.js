/** @type {import('tailwindcss').Config} */

const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    "./index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Chakra Petch', ...defaultTheme.fontFamily.sans],
        ui: ['var(--font-sans)'],
        mono: ['var(--font-mono)'],
      },
      colors: {
        accent: 'var(--accent)',
        ink: 'var(--ink)',
        'ink-soft': 'var(--ink-soft)',
        muted: 'var(--muted)',
        faint: 'var(--faint)',
        line: 'var(--border)',
        'line-soft': 'var(--border-soft)',
        'surface-muted': 'var(--surface-muted)',
        'surface-sunken': 'var(--surface-sunken)',
        'surface-subtle': 'var(--surface-subtle)',
        sidebar: 'var(--sidebar)',
        'sidebar-muted': 'var(--sidebar-muted)',
        danger: 'var(--danger)',
        'danger-text': 'var(--danger-text)',
      },
      textShadow: {
        'sm': '0 0px 2px rgba(255, 255, 255, 0.1)',
        'DEFAULT': '0 0px 4px rgba(255, 255, 255, 0.1)',
        'md': '0 0px 0px rgba(255, 255, 255, 0.12)',
        'lg': '0 0px 16px rgba(255, 255, 255, 0.15)',
        'white': '0 0px 4px rgba(255, 255, 255, 0.5)',
        'black': '0 0px 4px rgba(0, 0, 0, 0.5)',
        'gray': '0 0px 4px rgba(128, 128, 128, 0.5)',
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
    require("tailwindcss-animate"),
    require('@tailwindcss/typography'),
    function({ addUtilities, theme, matchUtilities }) {
      const textShadows = theme('textShadow')
      const utilities = Object.entries(textShadows).map(([key, value]) => {
        return {
          [`.text-shadow${key === 'DEFAULT' ? '' : `-${key}`}`]: {
            textShadow: value,
          }
        }
      })
      addUtilities(utilities)
      
      matchUtilities(
        {
          'text-shadow': (value) => ({
            textShadow: `0 0px 5px ${value}`,
          }),
        },
        { values: theme('colors') }
      )
    },
  ],
}
